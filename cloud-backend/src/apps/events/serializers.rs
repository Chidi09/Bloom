//! Serialization adapters for the `events` app.

use super::contracts::EventResponse;
use super::models::EventLog;

/// Serializes an [`EventLog`] row into its public wire [`EventResponse`].
///
/// The stored `payload` is JSON text; it is parsed back to a `serde_json::Value`
/// so the API never emits the raw string. An unparseable stored payload degrades
/// to JSON `null` rather than failing the response.
pub fn serialize_event(
    event: &EventLog,
    organization_public_id: Option<&str>,
    project_public_id: Option<&str>,
    app_public_id: Option<&str>,
    actor_public_id: Option<&str>,
) -> EventResponse {
    EventResponse {
        id: event.public_id.clone(),
        event_id: event.event_id.clone(),
        event_type: event.event_type.clone(),
        organization_id: organization_public_id.map(|s| s.to_string()),
        project_id: project_public_id.map(|s| s.to_string()),
        app_id: app_public_id.map(|s| s.to_string()),
        actor_id: actor_public_id.map(|s| s.to_string()),
        payload: serde_json::from_str(&event.payload).unwrap_or(serde_json::Value::Null),
        created_at: event.created_at.to_rfc3339(),
    }
}
