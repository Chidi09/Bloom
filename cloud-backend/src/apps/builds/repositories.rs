//! Database queries and persistence operations for the `builds` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{Build, BuildStage};

/// Fetch a `Build` by its internal primary key.
pub async fn build_by_id(db: &Database, id: i64) -> Result<Option<Build>, OrmError> {
    Build::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Build` by its external public UUID without organization scoping.
///
/// Used by the internal worker callbacks, where the authenticated caller is the
/// worker, not a tenant user.
pub async fn build_by_public_id(db: &Database, public_id: &str) -> Result<Option<Build>, OrmError> {
    Build::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Build` by its external public UUID within a specific organization.
pub async fn build_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Build>, OrmError> {
    Build::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List all builds belonging to an app within an organization, newest first.
pub async fn builds_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<Build>, OrmError> {
    Build::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all builds belonging to an environment within an organization, newest first.
pub async fn builds_for_environment(
    db: &Database,
    environment_id: i64,
    organization_id: i64,
) -> Result<Vec<Build>, OrmError> {
    Build::objects()
        .filter(q!(environment_id = environment_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all builds belonging to an organization, newest first.
pub async fn builds_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Build>, OrmError> {
    Build::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List builds with optional app or environment filter, and optional limit and offset.
pub async fn list_builds_query(
    db: &Database,
    organization_id: i64,
    app_id: Option<i64>,
    environment_id: Option<i64>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Build>, i64), OrmError> {
    let mut qs = Build::objects().filter(q!(organization_id = organization_id))?;
    if let Some(a_id) = app_id {
        qs = qs.filter(q!(app_id = a_id))?;
    }
    if let Some(e_id) = environment_id {
        qs = qs.filter(q!(environment_id = e_id))?;
    }
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// Insert a new `Build` record.
pub async fn insert_build(db: &Database, build: Build) -> Result<Build, OrmError> {
    build.save(db).await
}

/// Update an existing `Build` record.
pub async fn update_build(db: &Database, build: &Build) -> Result<(), OrmError> {
    build.update(db).await
}

/// Fetch a `BuildStage` by its parent build and stage name.
pub async fn buildstage_by_build_and_stage(
    db: &Database,
    build_id: i64,
    stage: &str,
) -> Result<Option<BuildStage>, OrmError> {
    BuildStage::objects()
        .filter(q!(build_id = build_id))?
        .filter(q!(stage = stage.to_owned()))?
        .first(db)
        .await
}

/// List all stages belonging to a build, in insertion order.
pub async fn buildstages_for_build(
    db: &Database,
    build_id: i64,
) -> Result<Vec<BuildStage>, OrmError> {
    BuildStage::objects()
        .filter(q!(build_id = build_id))?
        .order_by("id")?
        .all(db)
        .await
}

/// Insert a new `BuildStage` record.
pub async fn insert_buildstage(db: &Database, stage: BuildStage) -> Result<BuildStage, OrmError> {
    stage.save(db).await
}

/// Update an existing `BuildStage` record.
pub async fn update_buildstage(db: &Database, stage: &BuildStage) -> Result<(), OrmError> {
    stage.update(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (apps, environments, organizations) via the other
// apps' public models to avoid reaching into their tables directly.
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
    /// Internal primary key of the parent project.
    pub project_id: i64,
    /// Name of the app.
    pub name: String,
    /// Slug of the app.
    pub slug: String,
    /// Default Git branch of the app.
    pub default_branch: String,
}

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
}

/// Resolved summary for an environment entity.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key of the environment.
    pub id: i64,
    /// External public UUID of the environment.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Slug of the environment.
    pub slug: String,
    /// Default build profile.
    pub build_profile: String,
    /// Optional pinned Flutter version.
    pub flutter_version: Option<String>,
    /// Optional pinned Dart version.
    pub dart_version: Option<String>,
    /// Optional pinned Bloom CLI version.
    pub bloom_version: Option<String>,
    /// Optional build flavor.
    pub flavor: Option<String>,
}

/// Look up an app by its external public UUID within an organization.
///
/// Uses the `apps` app's public model through the ORM rather than raw SQL, per
/// docs/APP_PATTERN.md: repositories own QuerySet construction, and an app may not reach
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
        project_id: a.project_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
    }))
}

/// Look up an environment by its external public UUID within an organization.
pub async fn environment_by_public_id_and_org(
    db: &Database,
    environment_public_id: &str,
    organization_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(public_id = environment_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;

    Ok(found.map(|e| EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        organization_id: e.organization_id,
        app_id: e.app_id,
        slug: e.slug,
        build_profile: e.build_profile,
        flutter_version: e.flutter_version,
        dart_version: e.dart_version,
        bloom_version: e.bloom_version,
        flavor: e.flavor,
    }))
}

/// Look up an app's external public UUID by its internal primary key.
pub async fn app_public_id_by_id(db: &Database, app_id: i64) -> Result<Option<String>, OrmError> {
    let found = crate::apps::apps::models::App::objects()
        .filter(q!(id = app_id))?
        .first(db)
        .await?;

    Ok(found.map(|a| a.public_id))
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
        project_id: a.project_id,
        name: a.name,
        slug: a.slug,
        default_branch: a.default_branch,
    }))
}

/// Look up an environment's external public UUID by its internal primary key.
pub async fn environment_public_id_by_id(
    db: &Database,
    environment_id: i64,
) -> Result<Option<String>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(id = environment_id))?
        .first(db)
        .await?;

    Ok(found.map(|e| e.public_id))
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

/// Look up a project's external public UUID by its internal primary key.
pub async fn project_public_id_by_id(
    db: &Database,
    project_id: i64,
) -> Result<Option<String>, OrmError> {
    let found = crate::apps::projects::models::Project::objects()
        .filter(q!(id = project_id))?
        .first(db)
        .await?;

    Ok(found.map(|p| p.public_id))
}

/// Look up multiple apps' external public UUIDs by their internal primary keys in one batch.
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
    for app in apps {
        map.insert(app.id, app.public_id);
    }
    Ok(map)
}

/// Look up multiple environments' external public UUIDs by their internal primary keys in one batch.
pub async fn environment_public_ids_by_ids(
    db: &Database,
    env_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if env_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let envs = crate::apps::environments::models::Environment::objects()
        .filter(djangors_orm::q!(id__in = env_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(envs.len());
    for env in envs {
        map.insert(env.id, env.public_id);
    }
    Ok(map)
}
