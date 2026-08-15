//! Database queries and persistence operations for the `apps` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::App;

/// Fetch an `App` by its internal primary key.
pub async fn app_by_id(db: &Database, id: i64) -> Result<Option<App>, OrmError> {
    App::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an `App` by its external public UUID within a specific organization.
pub async fn app_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<App>, OrmError> {
    App::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch an `App` by its unique slug within a project and organization.
pub async fn app_by_project_and_slug(
    db: &Database,
    project_id: i64,
    slug: &str,
) -> Result<Option<App>, OrmError> {
    App::objects()
        .filter(q!(project_id = project_id))?
        .filter(q!(slug = slug.to_owned()))?
        .first(db)
        .await
}

/// Check if an app slug already exists within a project.
pub async fn app_slug_exists_in_project(
    db: &Database,
    project_id: i64,
    slug: &str,
) -> Result<bool, OrmError> {
    App::objects()
        .filter(q!(project_id = project_id))?
        .filter(q!(slug = slug.to_owned()))?
        .exists(db)
        .await
}

/// List all apps belonging to a project within an organization.
pub async fn apps_for_project(
    db: &Database,
    project_id: i64,
    organization_id: i64,
) -> Result<Vec<App>, OrmError> {
    App::objects()
        .filter(q!(project_id = project_id))?
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// List all apps belonging to an organization.
pub async fn apps_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<App>, OrmError> {
    App::objects()
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// Insert a new `App` record.
pub async fn insert_app(db: &Database, app: App) -> Result<App, OrmError> {
    app.save(db).await
}

/// Update an existing `App` record.
pub async fn update_app(db: &Database, app: &App) -> Result<(), OrmError> {
    app.update(db).await
}

/// Delete an `App` record by its internal primary key.
pub async fn delete_app_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    App::objects().filter(q!(id = id))?.delete(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (projects, organizations) via plain SQL queries to
// avoid direct module dependencies on apps being developed in parallel.
// ---------------------------------------------------------------------------

/// Resolved metadata for a project.
#[derive(Debug, Clone)]
pub struct ProjectSummary {
    /// Internal primary key of the project.
    pub id: i64,
    /// External public UUID of the project.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Slug of the project.
    pub slug: String,
}

/// Resolved metadata for an organization.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
}

/// Look up a project by its external public UUID within an organization.
///
/// Uses the `projects` app's public model through the ORM rather than raw SQL, per
/// APP_PATTERN.md: repositories own QuerySet construction and must not reach into
/// another app's tables directly.
pub async fn project_by_public_id_and_org(
    db: &Database,
    project_public_id: &str,
    organization_id: i64,
) -> Result<Option<ProjectSummary>, OrmError> {
    let found = crate::apps::projects::models::Project::objects()
        .filter(q!(public_id = project_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| ProjectSummary {
        id: p.id,
        public_id: p.public_id,
        organization_id: p.organization_id.id,
        slug: p.slug,
    }))
}

/// Look up a project by its slug within an organization.
pub async fn project_by_slug_and_org(
    db: &Database,
    project_slug: &str,
    organization_id: i64,
) -> Result<Option<ProjectSummary>, OrmError> {
    let found = crate::apps::projects::models::Project::objects()
        .filter(q!(slug = project_slug.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| ProjectSummary {
        id: p.id,
        public_id: p.public_id,
        organization_id: p.organization_id.id,
        slug: p.slug,
    }))
}

/// Look up a project summary by its internal primary key.
pub async fn project_summary_by_id(
    db: &Database,
    project_id: i64,
) -> Result<Option<ProjectSummary>, OrmError> {
    let found = crate::apps::projects::models::Project::objects()
        .filter(q!(id = project_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| ProjectSummary {
        id: p.id,
        public_id: p.public_id,
        organization_id: p.organization_id.id,
        slug: p.slug,
    }))
}

/// Look up an organization summary by its internal primary key.
pub async fn organization_summary_by_id(
    db: &Database,
    organization_id: i64,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
    }))
}

/// Check if an app has associated child records that block deletion.
///
/// Only `environments` is checked here: it is the sole child model that exists today.
/// TODO(spec): extend to `builds` and `releases` once those apps land (PHASES.md Phase 3
/// and Phase 4). This previously issued raw SQL against `builds_build` and
/// `releases_release` — tables no migration creates — inside `if let Ok(..)`, so those
/// checks silently evaluated to "no children" and would have permitted deleting an app
/// that still had builds or releases.
pub async fn app_has_children(db: &Database, app_id: i64) -> Result<bool, OrmError> {
    crate::apps::environments::models::Environment::objects()
        .filter(q!(app_id = app_id))?
        .exists(db)
        .await
}
