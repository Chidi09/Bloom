//! Persistence models for the `events` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// A durable event-log row recording a single state change in Bloom Cloud.
///
/// Events are immutable. They are written only through the app's public service
/// interface (`record_event` / `emit`) and read through the organization-scoped
/// list and retrieve endpoints. Foreign keys are stored as plain internal `i64`s
/// (`None` when not applicable) so this model does not depend on every other app.
#[derive(Model, Debug, Clone)]
#[djangors(app = "events", table_name = "events_eventlog")]
pub struct EventLog {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4), exposed as `id` over the wire.
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// The event's own UUID v4 identifier.
    #[djangors(max_length = 36, unique)]
    pub event_id: String,

    /// Dot-separated event type, e.g. `build.started`.
    #[djangors(max_length = 128, db_index)]
    pub event_type: String,

    /// Internal id of the organization the event belongs to, if any.
    #[djangors(db_index)]
    pub organization_id: Option<i64>,

    /// Internal id of the project the event belongs to, if any.
    pub project_id: Option<i64>,

    /// Internal id of the app the event belongs to, if any.
    #[djangors(db_index)]
    pub app_id: Option<i64>,

    /// Internal id of the acting user; `None` means a system action.
    pub actor_id: Option<i64>,

    /// Event payload serialized as JSON text.
    pub payload: String,

    /// Creation timestamp.
    #[djangors(auto_now_add, db_index)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for EventLog {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
