//! Database queries and persistence operations for the `releases` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::Release;

/// Fetch a `Release` by its internal primary key.
pub async fn release_by_id(db: &Database, id: i64) -> Result<Option<Release>, OrmError> {
    Release::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Release` by its external public UUID.
pub async fn release_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Release>, OrmError> {
    Release::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Release` by its external public UUID within a specific organization.
pub async fn release_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Release>, OrmError> {
    Release::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List releases belonging to an app within an organization, newest first.
pub async fn releases_for_app(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<Release>, OrmError> {
    Release::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List releases belonging to an environment within an organization, newest first.
pub async fn releases_for_environment(
    db: &Database,
    environment_id: i64,
    organization_id: i64,
) -> Result<Vec<Release>, OrmError> {
    Release::objects()
        .filter(q!(environment_id = environment_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all releases belonging to an organization, newest first.
pub async fn releases_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Release>, OrmError> {
    Release::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List releases with optional app, environment, and status filters, with limit and offset.
pub async fn list_releases_query(
    db: &Database,
    organization_id: i64,
    app_id: Option<i64>,
    environment_id: Option<i64>,
    status: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Release>, i64), OrmError> {
    let mut qs = Release::objects().filter(q!(organization_id = organization_id))?;
    if let Some(a_id) = app_id {
        qs = qs.filter(q!(app_id = a_id))?;
    }
    if let Some(e_id) = environment_id {
        qs = qs.filter(q!(environment_id = e_id))?;
    }
    if let Some(s) = status {
        if !s.trim().is_empty() {
            qs = qs.filter(q!(status = s.trim().to_owned()))?;
        }
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

/// Insert a new `Release` record.
pub async fn insert_release(db: &Database, release: Release) -> Result<Release, OrmError> {
    release.save(db).await
}

/// Update an existing `Release` record.
pub async fn update_release(db: &Database, release: &Release) -> Result<(), OrmError> {
    release.update(db).await
}

/// Delete a `Release` by its internal primary key.
pub async fn delete_release_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Release::objects().filter(q!(id = id))?.delete(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (organizations, apps, environments, artifacts, builds, users)
// via the owning app's public model through the ORM — never raw SQL against another app's table.
// ---------------------------------------------------------------------------

/// Resolved metadata for an organization.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID of the organization.
    pub public_id: String,
}

/// Resolved metadata for an application entity.
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
}

/// Resolved metadata for an environment.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key of the environment.
    pub id: i64,
    /// External public UUID of the environment.
    pub public_id: String,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
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

/// Look up an app by its external public UUID within an organization.
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
        project_id: a.project_id,
    }))
}

/// Look up an environment by its external public UUID within an organization.
pub async fn environment_by_public_id_and_org(
    db: &Database,
    env_public_id: &str,
    organization_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(public_id = env_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|e| EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        app_id: e.app_id,
        organization_id: e.organization_id,
    }))
}

/// Look up an environment summary by its internal primary key.
pub async fn environment_summary_by_id(
    db: &Database,
    environment_id: i64,
) -> Result<Option<EnvironmentSummary>, OrmError> {
    let found = crate::apps::environments::models::Environment::objects()
        .filter(q!(id = environment_id))?
        .first(db)
        .await?;
    Ok(found.map(|e| EnvironmentSummary {
        id: e.id,
        public_id: e.public_id,
        app_id: e.app_id,
        organization_id: e.organization_id,
    }))
}

/// Look up an artifact by its public UUID within an organization.
pub async fn artifact_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<crate::apps::artifacts::models::Artifact>, OrmError> {
    crate::apps::artifacts::models::Artifact::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Look up a build's public UUID by its internal primary key.
pub async fn build_public_id_by_id(
    db: &Database,
    build_id: i64,
) -> Result<Option<String>, OrmError> {
    let found = crate::apps::builds::models::Build::objects()
        .filter(q!(id = build_id))?
        .first(db)
        .await?;
    Ok(found.map(|b| b.public_id))
}

/// Look up a user profile public ID by the user's internal auth ID.
pub async fn user_public_id_by_id(db: &Database, user_id: i64) -> Result<Option<String>, OrmError> {
    let found = crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id = user_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| p.public_id))
}

/// Look up multiple apps' summaries by their internal primary keys in one batch.
pub async fn app_summaries_by_ids(
    db: &Database,
    app_ids: &[i64],
) -> Result<std::collections::HashMap<i64, AppSummary>, OrmError> {
    if app_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let apps = crate::apps::apps::models::App::objects()
        .filter(djangors_orm::q!(id__in = app_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(apps.len());
    for a in apps {
        map.insert(
            a.id,
            AppSummary {
                id: a.id,
                public_id: a.public_id,
                organization_id: a.organization_id,
                project_id: a.project_id,
            },
        );
    }
    Ok(map)
}

/// Look up multiple environments' summaries by their internal primary keys in one batch.
pub async fn environment_summaries_by_ids(
    db: &Database,
    env_ids: &[i64],
) -> Result<std::collections::HashMap<i64, EnvironmentSummary>, OrmError> {
    if env_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let envs = crate::apps::environments::models::Environment::objects()
        .filter(djangors_orm::q!(id__in = env_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(envs.len());
    for e in envs {
        map.insert(
            e.id,
            EnvironmentSummary {
                id: e.id,
                public_id: e.public_id,
                app_id: e.app_id,
                organization_id: e.organization_id,
            },
        );
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

/// Look up multiple artifacts by public UUID within an organization in one batch.
pub async fn artifacts_by_public_ids_and_org(
    db: &Database,
    public_ids: &[String],
    organization_id: i64,
) -> Result<std::collections::HashMap<String, crate::apps::artifacts::models::Artifact>, OrmError> {
    if public_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let artifacts = crate::apps::artifacts::models::Artifact::objects()
        .filter(djangors_orm::q!(public_id__in = public_ids.to_vec()))?
        .filter(djangors_orm::q!(organization_id = organization_id))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(artifacts.len());
    for a in artifacts {
        map.insert(a.public_id.clone(), a);
    }
    Ok(map)
}

/// Look up multiple builds' public UUIDs by their internal primary keys in one batch.
pub async fn build_public_ids_by_ids(
    db: &Database,
    build_ids: &[i64],
) -> Result<std::collections::HashMap<i64, String>, OrmError> {
    if build_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let builds = crate::apps::builds::models::Build::objects()
        .filter(djangors_orm::q!(id__in = build_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(builds.len());
    for b in builds {
        map.insert(b.id, b.public_id);
    }
    Ok(map)
}
