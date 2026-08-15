//! Database queries and persistence operations for the `artifacts` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::Artifact;

/// Fetch an `Artifact` by its internal primary key.
pub async fn artifact_by_id(db: &Database, id: i64) -> Result<Option<Artifact>, OrmError> {
    Artifact::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an `Artifact` by its external public UUID within a specific organization.
pub async fn artifact_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Artifact>, OrmError> {
    Artifact::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List artifacts belonging to a build within an organization, newest first.
pub async fn artifacts_for_build(
    db: &Database,
    build_id: i64,
    organization_id: i64,
) -> Result<Vec<Artifact>, OrmError> {
    Artifact::objects()
        .filter(q!(build_id = build_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all artifacts belonging to an organization, newest first.
pub async fn artifacts_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Artifact>, OrmError> {
    Artifact::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List artifacts with optional build filter, with limit and offset.
pub async fn list_artifacts_query(
    db: &Database,
    organization_id: i64,
    build_id: Option<i64>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Artifact>, i64), OrmError> {
    let mut qs = Artifact::objects().filter(q!(organization_id = organization_id))?;
    if let Some(b_id) = build_id {
        qs = qs.filter(q!(build_id = b_id))?;
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

/// Insert a new `Artifact` record.
pub async fn insert_artifact(db: &Database, artifact: Artifact) -> Result<Artifact, OrmError> {
    artifact.save(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (organizations, apps, projects, builds) via the owning
// app's public model through the ORM — never raw SQL against another app's table.
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

/// Resolved metadata for a project.
#[derive(Debug, Clone)]
pub struct ProjectSummary {
    /// Internal primary key of the project.
    pub id: i64,
    /// External public UUID of the project.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
}

/// Resolved metadata for a build.
#[derive(Debug, Clone)]
pub struct BuildSummary {
    /// Internal primary key of the build.
    pub id: i64,
    /// External public UUID of the build.
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

/// Look up an organization summary by its external public UUID.
pub async fn organization_summary_by_public_id(
    db: &Database,
    organization_public_id: &str,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(public_id = organization_public_id.to_owned()))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
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
    }))
}

// ---------------------------------------------------------------------------
// Build lookups.
//
// Projected from the `builds` app's public model, per docs/APP_PATTERN.md: an app reaches
// another app's rows through its model type, never raw SQL against its table.
// `Build::app_id` is a `ForeignKey<App>` (hence `.id`); `Build::organization_id` is a
// denormalized plain `i64`.
// ---------------------------------------------------------------------------

/// Project a `Build` model onto the local summary shape.
fn build_summary(b: crate::apps::builds::models::Build) -> BuildSummary {
    BuildSummary {
        id: b.id,
        public_id: b.public_id,
        app_id: b.app_id.id,
        organization_id: b.organization_id,
    }
}

/// Look up a build summary by its internal primary key.
pub async fn build_summary_by_id(
    db: &Database,
    build_id: i64,
) -> Result<Option<BuildSummary>, OrmError> {
    let found = crate::apps::builds::models::Build::objects()
        .filter(q!(id = build_id))?
        .first(db)
        .await?;
    Ok(found.map(build_summary))
}

/// Look up a build summary by its external public UUID within an organization.
pub async fn build_summary_by_public_id_and_org(
    db: &Database,
    build_public_id: &str,
    organization_id: i64,
) -> Result<Option<BuildSummary>, OrmError> {
    let found = crate::apps::builds::models::Build::objects()
        .filter(q!(public_id = build_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(build_summary))
}

/// Look up multiple build summaries by their internal primary keys in one batch.
pub async fn build_summaries_by_ids(
    db: &Database,
    build_ids: &[i64],
) -> Result<std::collections::HashMap<i64, BuildSummary>, OrmError> {
    if build_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let builds = crate::apps::builds::models::Build::objects()
        .filter(djangors_orm::q!(id__in = build_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(builds.len());
    for b in builds {
        map.insert(b.id, build_summary(b));
    }
    Ok(map)
}
