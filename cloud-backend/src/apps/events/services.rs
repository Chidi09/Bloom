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
    let project_filter = match project_id {
        Some(public_id) => {
            match repositories::project_id_by_public_id(db, public_id, organization_id).await? {
                Some(id) => Some(id),
                None => return Ok(Vec::new()),
            }
        }
        None => None,
    };

    let app_filter = match app_id {
        Some(public_id) => {
            match repositories::app_id_by_public_id(db, public_id, organization_id).await? {
                Some(id) => Some(id),
                None => return Ok(Vec::new()),
            }
        }
        None => None,
    };

    let events = repositories::list_events(db, qs, event_type, project_filter, app_filter).await?;
    let organization_public_id = repositories::organization_public_id(db, organization_id).await?;

    let mut responses = Vec::with_capacity(events.len());
    for event in &events {
        responses.push(resolve_event_response(db, event, organization_public_id.as_deref()).await?);
    }
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
