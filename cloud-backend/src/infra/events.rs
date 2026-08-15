//! Real-time event fan-out over Redis pub/sub.
//!
//! `docs/infrastructure.md` section 3 specifies that every state change is both stored in the
//! `events_eventlog` table and published to a Redis channel for live dashboard updates. Only
//! the first half existed: `apps::events::services::emit` wrote a row and stopped, so the
//! dashboard's only option was polling an unbounded table. This module is the missing half.
//!
//! # Delivery guarantees
//!
//! Redis pub/sub is fire-and-forget. A subscriber that is not connected at publish time never
//! receives the message, and there is no replay. This channel is therefore a **liveness**
//! signal, not a log: a client that needs completeness reconciles against the paginated
//! `GET /events` endpoint, which reads the durable table. Nothing here should ever be treated
//! as the system of record.

use futures_util::{Stream, StreamExt};

/// Redis pub/sub channel carrying every organization's events.
///
/// A single channel with per-subscriber filtering is used rather than a channel per
/// organization: Redis pattern subscriptions across thousands of tenant channels cost more
/// than filtering a modest event volume in the subscriber, and one channel keeps the publish
/// path a single round trip regardless of tenant count.
pub const EVENT_CHANNEL: &str = "bloomcloud:events";

/// Errors raised while publishing or subscribing to the event channel.
#[derive(Debug)]
pub enum EventBusError {
    /// The Redis connection could not be established.
    Connection(String),
    /// The event payload could not be serialized or the publish command failed.
    Publish(String),
    /// Subscribing to the channel failed.
    Subscribe(String),
}

impl std::fmt::Display for EventBusError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Connection(msg) => write!(f, "event bus connection failed: {msg}"),
            Self::Publish(msg) => write!(f, "event publish failed: {msg}"),
            Self::Subscribe(msg) => write!(f, "event subscribe failed: {msg}"),
        }
    }
}

impl std::error::Error for EventBusError {}

/// Publishes and subscribes to the live event channel.
#[derive(Clone)]
pub struct EventBus {
    redis: redis::Client,
}

impl EventBus {
    /// Creates a bus over an existing Redis client.
    pub fn new(redis: redis::Client) -> Self {
        Self { redis }
    }

    /// Creates a bus from a Redis connection URL.
    pub fn from_url(redis_url: &str) -> Result<Self, EventBusError> {
        let client =
            redis::Client::open(redis_url).map_err(|e| EventBusError::Connection(e.to_string()))?;
        Ok(Self::new(client))
    }

    /// Publishes one serialized event to the channel.
    ///
    /// `payload` must be the same JSON shape `GET /events` returns, so a client can parse both
    /// with one type. It must carry the owning organization's public UUID under
    /// `organization_id`, since that is the only thing [`subscribe_for_organization`] has to
    /// decide who may see it.
    ///
    /// [`subscribe_for_organization`]: EventBus::subscribe_for_organization
    pub async fn publish(&self, payload: &serde_json::Value) -> Result<(), EventBusError> {
        let encoded =
            serde_json::to_string(payload).map_err(|e| EventBusError::Publish(e.to_string()))?;

        let mut conn = self
            .redis
            .get_multiplexed_async_connection()
            .await
            .map_err(|e| EventBusError::Connection(e.to_string()))?;

        redis::cmd("PUBLISH")
            .arg(EVENT_CHANNEL)
            .arg(encoded)
            .query_async::<()>(&mut conn)
            .await
            .map_err(|e| EventBusError::Publish(e.to_string()))?;

        Ok(())
    }

    /// Subscribes to the channel, yielding only events belonging to `organization_public_id`.
    ///
    /// The filter is the entire tenant boundary for this stream. The channel carries every
    /// organization's events, so an event whose `organization_id` does not match, or which
    /// carries no `organization_id` at all, is dropped rather than forwarded — a malformed
    /// payload must not become a cross-tenant leak.
    ///
    /// Dropping the returned stream tears down the Redis subscription, so a disconnected
    /// client releases its connection without further action from the caller.
    pub async fn subscribe_for_organization(
        &self,
        organization_public_id: String,
    ) -> Result<impl Stream<Item = String> + Send, EventBusError> {
        let mut pubsub = self
            .redis
            .get_async_pubsub()
            .await
            .map_err(|e| EventBusError::Connection(e.to_string()))?;

        pubsub
            .subscribe(EVENT_CHANNEL)
            .await
            .map_err(|e| EventBusError::Subscribe(e.to_string()))?;

        Ok(pubsub.into_on_message().filter_map(move |msg| {
            let organization_public_id = organization_public_id.clone();
            async move {
                let raw: String = msg.get_payload().ok()?;
                let parsed: serde_json::Value = serde_json::from_str(&raw).ok()?;
                let owner = parsed.get("organization_id")?.as_str()?;

                if owner == organization_public_id {
                    Some(raw)
                } else {
                    None
                }
            }
        }))
    }
}

/// Returns true when `payload` belongs to `organization_public_id`.
///
/// Extracted so the tenant rule can be tested without a Redis server; the subscription applies
/// exactly this predicate.
pub fn event_belongs_to_organization(
    payload: &serde_json::Value,
    organization_public_id: &str,
) -> bool {
    payload
        .get("organization_id")
        .and_then(|v| v.as_str())
        .is_some_and(|owner| owner == organization_public_id)
}
