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

/// Optional filters accepted by the deployment list endpoint.
///
/// Grouped into a struct rather than passed as five separate positional `Option`s: adjacent
/// same-typed parameters are trivially transposable at a call site, and a swapped
/// `platform`/`target` pair would silently return the wrong rows rather than fail to compile.
#[derive(Debug, Clone, Copy, Default)]
pub struct DeploymentFilters<'a> {
    /// Internal primary key of the release to filter by.
    pub release_id: Option<i64>,
    /// Internal primary key of the environment to filter by.
    pub environment_id: Option<i64>,
    /// Target platform (`android`, `ios`, `web`).
    pub platform: Option<&'a str>,
    /// Deployment target (`app_store`, `play_store`, `web`, ...).
    pub target: Option<&'a str>,
    /// Deployment lifecycle status.
    pub status: Option<&'a str>,
}

/// List deployments with optional filters and cursor keyset pagination.
/// Fetches `limit + 1` rows to determine whether there is a next page.
/// Explicit deterministic ordering by `-created_at` then `-id`.
pub async fn list_deployments_cursor(
    db: &Database,
    organization_id: i64,
    filters: &DeploymentFilters<'_>,
    cursor: Option<&str>,
    limit: i64,
) -> Result<(Vec<Deployment>, Option<String>), OrmError> {
    let mut qs = Deployment::objects().filter(q!(organization_id = organization_id))?;
    if let Some(r_id) = filters.release_id {
        qs = qs.filter(q!(release_id = r_id))?;
    }
    if let Some(e_id) = filters.environment_id {
        qs = qs.filter(q!(environment_id = e_id))?;
    }
    if let Some(p) = filters.platform {
        qs = qs.filter(q!(platform = p.to_owned()))?;
    }
    if let Some(t) = filters.target {
        qs = qs.filter(q!(target = t.to_owned()))?;
    }
    if let Some(s) = filters.status {
        qs = qs.filter(q!(status = s.to_owned()))?;
    }

    // No COUNT here. Keyset paging exists precisely so an unbounded, append-heavy log is
    // never scanned in full to answer a page request; issuing a COUNT alongside it would
    // reintroduce the cost the strategy was chosen to avoid.
    qs = crate::apps::common::pagination::apply_datetime_cursor(qs, cursor, "created_at", true)?;
    qs = qs.order_by("-created_at")?.order_by("-id")?;

    let fetched = qs.limit(limit + 1).all(db).await?;
    let has_next = fetched.len() > limit as usize;
    let items: Vec<Deployment> = fetched.into_iter().take(limit as usize).collect();

    let next_cursor = items.last().and_then(|last| {
        crate::apps::common::pagination::encode_datetime_cursor(has_next, last.id, last.created_at)
    });

    Ok((items, next_cursor))
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
                name: e.name,
                slug: e.slug,
            },
        );
    }
    Ok(map)
}

/// Look up multiple releases' summaries by their internal primary keys in one batch.
pub async fn release_summaries_by_ids(
    db: &Database,
    rel_ids: &[i64],
) -> Result<std::collections::HashMap<i64, ReleaseSummary>, OrmError> {
    if rel_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let releases = crate::apps::releases::models::Release::objects()
        .filter(djangors_orm::q!(id__in = rel_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(releases.len());
    for r in releases {
        map.insert(r.id, release_summary(r));
    }
    Ok(map)
}

/// Look up multiple artifacts' summaries by their internal primary keys in one batch.
pub async fn artifact_summaries_by_ids(
    db: &Database,
    art_ids: &[i64],
) -> Result<std::collections::HashMap<i64, ArtifactSummary>, OrmError> {
    if art_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let artifacts = crate::apps::artifacts::models::Artifact::objects()
        .filter(djangors_orm::q!(id__in = art_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(artifacts.len());
    for art in artifacts {
        map.insert(
            art.id,
            ArtifactSummary {
                id: art.id,
                public_id: art.public_id,
                organization_id: art.organization_id,
                platform: art.platform,
                kind: art.kind,
                storage_key: art.storage_key,
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
