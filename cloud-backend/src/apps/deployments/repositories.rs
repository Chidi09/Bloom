//! Database queries and persistence operations for the `deployments` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::Deployment;

/// Fetch a `Deployment` by its internal primary key.
pub async fn deployment_by_id(db: &Database, id: i64) -> Result<Option<Deployment>, OrmError> {
    Deployment::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Deployment` by its external public UUID.
pub async fn deployment_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Deployment>, OrmError> {
    Deployment::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Deployment` by its external public UUID within a specific organization.
pub async fn deployment_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Deployment>, OrmError> {
    Deployment::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// List all deployments in an organization, newest first.
pub async fn deployments_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Deployment>, OrmError> {
    Deployment::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List deployments for a specific release within an organization, newest first.
pub async fn deployments_for_release(
    db: &Database,
    release_id: i64,
    organization_id: i64,
) -> Result<Vec<Deployment>, OrmError> {
    Deployment::objects()
        .filter(q!(release_id = release_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List deployments for a specific environment within an organization, newest first.
pub async fn deployments_for_environment(
    db: &Database,
    environment_id: i64,
    organization_id: i64,
) -> Result<Vec<Deployment>, OrmError> {
    Deployment::objects()
        .filter(q!(environment_id = environment_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Insert a new `Deployment` record.
pub async fn insert_deployment(
    db: &Database,
    deployment: Deployment,
) -> Result<Deployment, OrmError> {
    deployment.save(db).await
}

/// Update an existing `Deployment` record.
pub async fn update_deployment(db: &Database, deployment: &Deployment) -> Result<(), OrmError> {
    deployment.update(db).await
}

// ---------------------------------------------------------------------------
// External entity lookups (organizations, environments, releases, artifacts, users)
// via the owning app's public model through the ORM — never raw SQL against another app's table.
// ---------------------------------------------------------------------------

/// Resolved summary for an organization entity.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
}

/// Resolved summary for an environment entity.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Human-readable name.
    pub name: String,
    /// URL slug.
    pub slug: String,
}

/// Resolved summary for a release entity.
#[derive(Debug, Clone)]
pub struct ReleaseSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the parent app.
    pub app_id: i64,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Semantic version.
    pub version: String,
    /// Release status.
    pub status: String,
    /// JSON list of artifact public UUID strings.
    pub artifacts: String,
}

/// Resolved summary for an artifact entity.
#[derive(Debug, Clone)]
pub struct ArtifactSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Internal primary key of the owning organization.
    pub organization_id: i64,
    /// Target platform.
    pub platform: String,
    /// Artifact kind.
    pub kind: String,
    /// Canonical storage key.
    pub storage_key: String,
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
        name: e.name,
        slug: e.slug,
    }))
}

/// Look up an environment summary by its public UUID within an organization.
pub async fn environment_summary_by_public_id_and_org(
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
        app_id: e.app_id,
        organization_id: e.organization_id,
        name: e.name,
        slug: e.slug,
    }))
}

/// Project a `Release` model into local [`ReleaseSummary`].
fn release_summary(r: crate::apps::releases::models::Release) -> ReleaseSummary {
    ReleaseSummary {
        id: r.id,
        public_id: r.public_id,
        app_id: r.app_id.id,
        organization_id: r.organization_id,
        version: r.version,
        status: r.status,
        artifacts: r.artifacts,
    }
}

/// Look up a release summary by its internal primary key.
pub async fn release_summary_by_id(
    db: &Database,
    release_id: i64,
) -> Result<Option<ReleaseSummary>, OrmError> {
    let found = crate::apps::releases::models::Release::objects()
        .filter(q!(id = release_id))?
        .first(db)
        .await?;
    Ok(found.map(release_summary))
}

/// Look up a release summary by its public UUID within an organization.
pub async fn release_summary_by_public_id_and_org(
    db: &Database,
    release_public_id: &str,
    organization_id: i64,
) -> Result<Option<ReleaseSummary>, OrmError> {
    let found = crate::apps::releases::models::Release::objects()
        .filter(q!(public_id = release_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(release_summary))
}

/// Look up an artifact summary by its internal primary key.
pub async fn artifact_summary_by_id(
    db: &Database,
    artifact_id: i64,
) -> Result<Option<ArtifactSummary>, OrmError> {
    let found = crate::apps::artifacts::models::Artifact::objects()
        .filter(q!(id = artifact_id))?
        .first(db)
        .await?;
    Ok(found.map(|art| ArtifactSummary {
        id: art.id,
        public_id: art.public_id,
        organization_id: art.organization_id,
        platform: art.platform,
        kind: art.kind,
        storage_key: art.storage_key,
    }))
}

/// Look up an artifact summary by its public UUID within an organization.
pub async fn artifact_summary_by_public_id_and_org(
    db: &Database,
    artifact_public_id: &str,
    organization_id: i64,
) -> Result<Option<ArtifactSummary>, OrmError> {
    let found = crate::apps::artifacts::models::Artifact::objects()
        .filter(q!(public_id = artifact_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|art| ArtifactSummary {
        id: art.id,
        public_id: art.public_id,
        organization_id: art.organization_id,
        platform: art.platform,
        kind: art.kind,
        storage_key: art.storage_key,
    }))
}

/// Look up a user's public ID by internal primary key.
pub async fn user_public_id_by_id(db: &Database, user_id: i64) -> Result<Option<String>, OrmError> {
    let found = crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id = user_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| p.public_id))
}
