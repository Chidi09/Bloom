//! Business logic and the public event-recording service interface for `events`.
//!
//! The two functions other apps must use are [`record_event`] (propagating) and
//! [`emit`] (log-and-swallow). A caller that already holds internal `i64` ids can
//! record an event in one call, and a failure to record never fails the caller's
//! own write path.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::QuerySet;
use uuid::Uuid;

use super::contracts::EventResponse;
use super::errors::EventError;
use super::models::EventLog;
use super::{repositories, serializers};

/// Persist a single event to `events_eventlog` and return the stored row.
///
/// Generates a fresh `public_id` and `event_id` (UUID v4). `actor_id` of `None`
/// represents a system action. The payload is stored as compact JSON text.
pub async fn record_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) -> Result<EventLog, EventError> {
    let event = EventLog {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        event_id: Uuid::new_v4().to_string(),
        event_type: event_type.to_string(),
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload: payload.to_string(),
        created_at: Utc::now(),
    };

    repositories::insert_event(db, event)
        .await
        .map_err(Into::into)
}

/// Publishes an already-recorded event to the live channel for connected dashboards.
///
/// Publishing is best-effort and deliberately never fails the caller. The durable record is
/// the row written by [`record_event`]; the channel is a liveness signal that clients
/// reconcile against `GET /events`. Losing a publish costs a dashboard a moment of
/// freshness, and must never cost the caller its write.
///
/// `organization_public_id` is required for the fan-out to be tenant-safe: it is the only
/// field [`crate::infra::events::EventBus::subscribe_for_organization`] can filter on. An
/// event with no organization is not published at all, because a payload the subscriber
/// cannot attribute is one it cannot safely deliver to anyone.
pub async fn publish_live(
    bus: &crate::infra::events::EventBus,
    event: &EventLog,
    organization_public_id: Option<&str>,
) {
    let Some(organization_public_id) = organization_public_id else {
        return;
    };

    let payload = serde_json::json!({
        "id": event.public_id,
        "event_id": event.event_id,
        "event_type": event.event_type,
        "organization_id": organization_public_id,
        "payload": serde_json::from_str::<serde_json::Value>(&event.payload)
            .unwrap_or(serde_json::Value::Null),
        "created_at": event.created_at.to_rfc3339(),
    });

    if let Err(error) = bus.publish(&payload).await {
        // This crate has no logging framework; src/main.rs uses eprintln! for the same purpose.
        eprintln!(
            "failed to publish event {} to the live channel; continuing: {error}",
            event.event_type
        );
    }
}

/// Record an event without propagating a failure to the caller's write path.
///
/// Any recording error is logged with `tracing` and swallowed so that emitting
/// an event can never fail the caller's own write.
pub async fn emit(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    if let Err(error) = record_event(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await
    {
        // This crate has no logging framework; src/main.rs uses eprintln! for the same purpose.
        eprintln!("failed to record event {event_type}; continuing: {error}");
    }
}

/// Optional filters accepted by the event list endpoint, keyed by public UUID.
///
/// Grouped rather than passed positionally: three adjacent `Option<&str>` parameters are
/// transposable without a compile error, and swapping `project_id` with `app_id` would
/// silently return the wrong slice of the log.
#[derive(Debug, Clone, Copy, Default)]
pub struct EventListFilters<'a> {
    /// Event type name to filter by (e.g. `build.started`).
    pub event_type: Option<&'a str>,
    /// Public UUID of the project to filter by.
    pub project_id: Option<&'a str>,
    /// Public UUID of the app to filter by.
    pub app_id: Option<&'a str>,
}

/// List events in an organization, newest first, with optional filters and cursor keyset pagination.
///
/// Batch resolves project, app, and user foreign keys in one query each to eliminate N+1 queries.
pub async fn list_events_cursor(
    db: &Database,
    qs: QuerySet<EventLog>,
    filters: &EventListFilters<'_>,
    organization_id: i64,
    cursor: Option<&str>,
    limit: i64,
) -> Result<(Vec<EventResponse>, Option<String>), EventError> {
    let EventListFilters {
        event_type,
        project_id,
        app_id,
    } = *filters;

    let project_filter = match project_id {
        Some(public_id) => {
            match repositories::project_id_by_public_id(db, public_id, organization_id).await? {
                Some(id) => Some(id),
                None => return Ok((Vec::new(), None)),
            }
        }
        None => None,
    };

    let app_filter = match app_id {
        Some(public_id) => {
            match repositories::app_id_by_public_id(db, public_id, organization_id).await? {
                Some(id) => Some(id),
                None => return Ok((Vec::new(), None)),
            }
        }
        None => None,
    };

    let (events, next_cursor) = repositories::list_events_cursor(
        db,
        qs,
        event_type,
        project_filter,
        app_filter,
        cursor,
        limit,
    )
    .await?;

    let organization_public_id = repositories::organization_public_id(db, organization_id).await?;

    if events.is_empty() {
        return Ok((Vec::new(), next_cursor));
    }

    let mut project_ids: Vec<i64> = events.iter().filter_map(|e| e.project_id).collect();
    project_ids.sort_unstable();
    project_ids.dedup();
    let project_map = repositories::project_public_ids_by_ids(db, &project_ids).await?;

    let mut app_ids: Vec<i64> = events.iter().filter_map(|e| e.app_id).collect();
    app_ids.sort_unstable();
    app_ids.dedup();
    let app_map = repositories::app_public_ids_by_ids(db, &app_ids).await?;

    let mut user_ids: Vec<i64> = events.iter().filter_map(|e| e.actor_id).collect();
    user_ids.sort_unstable();
    user_ids.dedup();
    let user_map = repositories::user_public_ids_by_ids(db, &user_ids).await?;

    let mut responses = Vec::with_capacity(events.len());
    for event in &events {
        let project_public_id = event
            .project_id
            .and_then(|id| project_map.get(&id).map(|s| s.as_str()));
        let app_public_id = event
            .app_id
            .and_then(|id| app_map.get(&id).map(|s| s.as_str()));
        let actor_public_id = match event.actor_id {
            Some(id) => user_map.get(&id).map(|s| s.as_str()),
            None => Some("system"),
        };

        responses.push(serializers::serialize_event(
            event,
            organization_public_id.as_deref(),
            project_public_id,
            app_public_id,
            actor_public_id,
        ));
    }

    Ok((responses, next_cursor))
}

/// List events in an organization, newest first, with optional filters.
///
/// `project_id` and `app_id` arrive as public UUIDs and are resolved to the
/// scoping organization's internal ids before filtering. An unresolvable filter
/// matches no events (empty result).
pub async fn list_events(
    db: &Database,
    qs: QuerySet<EventLog>,
    event_type: Option<&str>,
    project_id: Option<&str>,
    app_id: Option<&str>,
    organization_id: i64,
) -> Result<Vec<EventResponse>, EventError> {
    let (responses, _) = list_events_cursor(
        db,
        qs,
        &EventListFilters {
            event_type,
            project_id,
            app_id,
        },
        organization_id,
        None,
        djangors_rest::pagination::REST_PER_PAGE,
    )
    .await?;
    Ok(responses)
}

/// Retrieve a single event by public UUID within an organization.
pub async fn get_event(
    db: &Database,
    qs: QuerySet<EventLog>,
    event_public_id: &str,
    organization_id: i64,
) -> Result<EventResponse, EventError> {
    let event = repositories::event_by_public_id(db, qs, event_public_id)
        .await?
        .ok_or(EventError::EventNotFound)?;
    let organization_public_id = repositories::organization_public_id(db, organization_id).await?;
    resolve_event_response(db, &event, organization_public_id.as_deref()).await
}

/// Serialize an event, resolving its internal foreign keys to public UUIDs.
///
/// A missing referenced row degrades to `None` for that field; a stored actor of
/// `None` (system action) serializes as `"system"`.
async fn resolve_event_response(
    db: &Database,
    event: &EventLog,
    organization_public_id: Option<&str>,
) -> Result<EventResponse, EventError> {
    let project_public_id = match event.project_id {
        Some(id) => repositories::project_public_id(db, id).await?,
        None => None,
    };
    let app_public_id = match event.app_id {
        Some(id) => repositories::app_public_id(db, id).await?,
        None => None,
    };
    let actor_public_id = match event.actor_id {
        Some(id) => repositories::user_public_id(db, id).await?,
        None => Some("system".to_string()),
    };

    Ok(serializers::serialize_event(
        event,
        organization_public_id,
        project_public_id.as_deref(),
        app_public_id.as_deref(),
        actor_public_id.as_deref(),
    ))
}
