//! Database access and QuerySet operations for the `events` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError, QuerySet};

use super::models::EventLog;

/// Fetch an `EventLog` by public UUID within an already-scoped queryset.
pub async fn event_by_public_id(
    db: &Database,
    qs: QuerySet<EventLog>,
    public_id: &str,
) -> Result<Option<EventLog>, OrmError> {
    qs.filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// List events from an already-scoped queryset, newest first, with optional
/// `event_type`, `project_id`, and `app_id` filters applied.
pub async fn list_events(
    db: &Database,
    qs: QuerySet<EventLog>,
    event_type: Option<&str>,
    project_id: Option<i64>,
    app_id: Option<i64>,
) -> Result<Vec<EventLog>, OrmError> {
    let mut qs = qs;
    if let Some(event_type) = event_type {
        qs = qs.filter(q!(event_type = event_type.to_owned()))?;
    }
    if let Some(project_id) = project_id {
        qs = qs.filter(q!(project_id = project_id))?;
    }
    if let Some(app_id) = app_id {
        qs = qs.filter(q!(app_id = app_id))?;
    }
    qs.order_by("-created_at")?.all(db).await
}

/// Insert a new `EventLog` row.
pub async fn insert_event(db: &Database, event: EventLog) -> Result<EventLog, OrmError> {
    event.save(db).await
}

// =========================================================================
// Public-UUID resolution for related rows (read through each owning app's
// model type and projected onto a local value, per the wire contract).
// =========================================================================

/// Resolve an organization's public UUID from its internal id, best-effort.
pub async fn organization_public_id(db: &Database, id: i64) -> Result<Option<String>, OrmError> {
    crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
        .map(|row| row.map(|org| org.public_id))
}

/// Resolve a project's public UUID from its internal id, best-effort.
pub async fn project_public_id(db: &Database, id: i64) -> Result<Option<String>, OrmError> {
    crate::apps::projects::models::Project::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
        .map(|row| row.map(|project| project.public_id))
}

/// Resolve an app's public UUID from its internal id, best-effort.
pub async fn app_public_id(db: &Database, id: i64) -> Result<Option<String>, OrmError> {
    crate::apps::apps::models::App::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
        .map(|row| row.map(|app| app.public_id))
}

/// Resolve a user's public UUID from the user's internal auth id, best-effort.
pub async fn user_public_id(db: &Database, id: i64) -> Result<Option<String>, OrmError> {
    crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id = id))?
        .first(db)
        .await
        .map(|row| row.map(|profile| profile.public_id))
}

/// Resolve a project's internal id from its public UUID, scoped to an organization.
pub async fn project_id_by_public_id(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<i64>, OrmError> {
    crate::apps::projects::models::Project::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
        .map(|row| row.map(|project| project.id))
}

/// Resolve an app's internal id from its public UUID, scoped to an organization.
pub async fn app_id_by_public_id(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<i64>, OrmError> {
    crate::apps::apps::models::App::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
        .map(|row| row.map(|app| app.id))
}
