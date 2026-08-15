//! Database queries and persistence operations for the `environments` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::Environment;

/// Fetch an `Environment` by its internal primary key.
pub async fn environment_by_id(db: &Database, id: i64) -> Result<Option<Environment>, OrmError> {
    Environment::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an `Environment` by its external public UUID within a specific organization.
pub async fn environment_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Environment>, OrmError> {
    Environment::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch an `Environment` by its unique slug within an app and organization.
pub async fn environment_by_app_and_slug(
    db: &Database,
    app_id: i64,
    slug: &str,
) -> Result<Option<Environment>, OrmError> {
    Environment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(slug = slug.to_owned()))?
        .first(db)
        .await
}

/// Check if an environment slug already exists within an app.
pub async fn environment_slug_exists_in_app(
    db: &Database,
    app_id: i64,
    slug: &str,
) -> Result<bool, OrmError> {
    Environment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(slug = slug.to_owned()))?
        .exists(db)
        .await
}

/// List all environments belonging to an app within an organization.
pub async fn environments_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<Environment>, OrmError> {
    Environment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// List all environments belonging to an organization.
pub async fn environments_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Environment>, OrmError> {
    Environment::objects()
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// Insert a new `Environment` record.
pub async fn insert_environment(db: &Database, env: Environment) -> Result<Environment, OrmError> {
    env.save(db).await
}

/// Update an existing `Environment` record.
pub async fn update_environment(db: &Database, env: &Environment) -> Result<(), OrmError> {
    env.update(db).await
}

/// Delete an `Environment` record by its internal primary key.
pub async fn delete_environment_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Environment::objects().filter(q!(id = id))?.delete(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (apps, organizations) via plain SQL queries to
// avoid direct module dependencies on apps being developed in parallel.
// ---------------------------------------------------------------------------

/// Resolved summary for an application entity.
#[derive(Debug, Clone)]
pub struct AppSummary {
    /// Internal primary key of the app.
    pub id: i64,
    /// External public UUID of the app.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Name of the app.
    pub name: String,
    /// Slug of the app.
    pub slug: String,
}

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
}

/// Look up an app by its external public UUID within an organization.
///
/// Uses the `apps` app's public model through the ORM rather than raw SQL, per
/// APP_PATTERN.md: repositories own QuerySet construction, and an app may not reach
/// into another app's tables directly.
pub async fn app_by_public_id_and_org(
    db: &Database,
    app_public_id: &str,
    organization_id: i64,
) -> Result<Option<AppSummary>, OrmError> {
    let found = crate::apps::apps::models::App::objects()
        .filter(q!(public_id = app_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;

    Ok(found.map(|a| AppSummary {
        id: a.id,
        public_id: a.public_id,
        organization_id: a.organization_id,
        name: a.name,
        slug: a.slug,
    }))
}

/// Look up an app summary by its internal primary key.
pub async fn app_summary_by_id(db: &Database, app_id: i64) -> Result<Option<AppSummary>, OrmError> {
    let found = crate::apps::apps::models::App::objects()
        .filter(q!(id = app_id))?
        .first(db)
        .await?;

    Ok(found.map(|a| AppSummary {
        id: a.id,
        public_id: a.public_id,
        organization_id: a.organization_id,
        name: a.name,
        slug: a.slug,
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
