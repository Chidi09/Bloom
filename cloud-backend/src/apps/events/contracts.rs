//! Request and response data contracts for the `events` app.

use serde::{Deserialize, Serialize};

/// Wire representation of a stored event, exposed by the read API.
///
/// Internal `i64` foreign keys are never exposed; each is represented by the
/// related row's public UUID string, and the log row's own `public_id` is
/// exposed as `id`. `payload` is the parsed form of the stored JSON text.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EventResponse {
    /// Public UUID identifier of the event-log row.
    pub id: String,
    /// The event's own UUID v4 identifier.
    pub event_id: String,
    /// Dot-separated event type, e.g. `build.started`.
    pub event_type: String,
    /// Public UUID of the organization, when the event is scoped to one.
    pub organization_id: Option<String>,
    /// Public UUID of the project, when the event concerns one.
    pub project_id: Option<String>,
    /// Public UUID of the app, when the event concerns one.
    pub app_id: Option<String>,
    /// Public UUID of the acting user, or `"system"` for automated actions.
    pub actor_id: Option<String>,
    /// Event payload parsed from the stored JSON text.
    pub payload: serde_json::Value,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}
