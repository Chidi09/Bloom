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

/// List events from an already-scoped queryset with cursor keyset pagination.
/// Fetches `limit + 1` rows to determine whether there is a next page.
/// Explicit deterministic ordering by `-created_at` then `-id`.
pub async fn list_events_cursor(
    db: &Database,
    qs: QuerySet<EventLog>,
    event_type: Option<&str>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    cursor: Option<&str>,
    limit: i64,
) -> Result<(Vec<EventLog>, Option<String>), OrmError> {
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

    qs = crate::apps::common::pagination::apply_datetime_cursor(qs, cursor, "created_at", true)?;
    qs = qs.order_by("-created_at")?.order_by("-id")?;

    let fetched = qs.limit(limit + 1).all(db).await?;
    let has_next = fetched.len() > limit as usize;
    let items: Vec<EventLog> = fetched.into_iter().take(limit as usize).collect();

    let next_cursor = if has_next {
        items.last().map(|last_event| {
            let dt_str = last_event.created_at.to_rfc3339();
            djangors_core::pagination::encode_cursor(last_event.id, Some(&dt_str))
        })
    } else {
        None
    };

    Ok((items, next_cursor))
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

/// Look up multiple projects' public UUIDs by their internal primary keys in one batch.
pub async fn project_public_ids_by_ids(
    db: &Database,
    project_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if project_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let projects = crate::apps::projects::models::Project::objects()
        .filter(djangors_orm::q!(id__in = project_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(projects.len());
    for p in projects {
        map.insert(p.id, p.public_id);
    }
    Ok(map)
}

/// Look up multiple apps' public UUIDs by their internal primary keys in one batch.
pub async fn app_public_ids_by_ids(
    db: &Database,
    app_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if app_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let apps = crate::apps::apps::models::App::objects()
        .filter(djangors_orm::q!(id__in = app_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(apps.len());
    for a in apps {
        map.insert(a.id, a.public_id);
    }
    Ok(map)
}

/// Look up multiple users' public UUIDs by their internal auth user IDs in one batch.
pub async fn user_public_ids_by_ids(
    db: &Database,
    user_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if user_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let profiles = crate::apps::accounts::models::UserProfile::objects()
        .filter(djangors_orm::q!(user_id__in = user_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(profiles.len());
    for p in profiles {
        map.insert(p.user_id, p.public_id);
    }
    Ok(map)
}
