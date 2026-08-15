//! Database access and persistence queries for the `observability` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{PlatformMetric, ReleaseHealthSnapshot};

/// Lightweight local projection of a `Release` row from the `releases` app.
#[derive(Debug, Clone)]
pub struct ReleaseSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID identifier.
    pub public_id: String,
    /// Parent application internal primary key.
    pub app_id: i64,
    /// Tenant organization internal primary key.
    pub organization_id: i64,
    /// Semver version string.
    pub version: String,
    /// Monotonically increasing build number.
    pub build_number: i64,
    /// Target environment internal primary key, if assigned.
    pub environment_id: Option<i64>,
    /// Release status (e.g. `released`, `rolling_out`, `approved`).
    pub status: String,
    /// Target platforms as JSON text.
    pub platforms: String,
}

/// Lightweight local projection of an `App` row from the `apps` app.
#[derive(Debug, Clone)]
pub struct AppSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID identifier.
    pub public_id: String,
    /// Tenant organization internal primary key.
    pub organization_id: i64,
    /// Parent project internal primary key.
    pub project_id: i64,
    /// Human-readable application name.
    pub name: String,
    /// URL-safe slug unique per project.
    pub slug: String,
}

/// Lightweight local projection of an `Environment` row from the `environments` app.
#[derive(Debug, Clone)]
pub struct EnvironmentSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID identifier.
    pub public_id: String,
    /// Parent app internal primary key.
    pub app_id: i64,
    /// Tenant organization internal primary key.
    pub organization_id: i64,
    /// Environment name.
    pub name: String,
    /// Environment slug (e.g. `production`).
    pub slug: String,
}

/// Lightweight local projection of a `Deployment` row from the `deployments` app.
///
// TODO(spec): parallel dispatch for deployments app will supply crate::apps::deployments::models::Deployment.
#[derive(Debug, Clone)]
pub struct DeploymentSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID identifier.
    pub public_id: String,
    /// Associated release internal primary key.
    pub release_id: i64,
    /// Platform name (e.g. `ios`, `android`, `web`).
    pub platform: String,
    /// Deployment target (e.g. `testflight`, `google_play`, `production`).
    pub target: String,
    /// Deployment status (e.g. `live`, `failed`, `processing`).
    pub status: String,
}

/// Insert a new [`ReleaseHealthSnapshot`] row.
pub async fn insert_snapshot(
    db: &Database,
    snapshot: ReleaseHealthSnapshot,
) -> Result<ReleaseHealthSnapshot, OrmError> {
    snapshot.save(db).await
}

/// Fetch all snapshots for a given release internal id, newest first.
pub async fn snapshots_for_release(
    db: &Database,
    release_id: i64,
) -> Result<Vec<ReleaseHealthSnapshot>, OrmError> {
    ReleaseHealthSnapshot::objects()
        .filter(q!(release_id = release_id))?
        .order_by("-captured_at")?
        .all(db)
        .await
}

/// Insert a new [`PlatformMetric`] row.
pub async fn insert_platform_metric(
    db: &Database,
    metric: PlatformMetric,
) -> Result<PlatformMetric, OrmError> {
    metric.save(db).await
}

/// Fetch all platform metrics for a given deployment internal id, newest first.
pub async fn metrics_for_deployment(
    db: &Database,
    deployment_id: i64,
) -> Result<Vec<PlatformMetric>, OrmError> {
    PlatformMetric::objects()
        .filter(q!(deployment_id = deployment_id))?
        .order_by("-captured_at")?
        .all(db)
        .await
}

// =========================================================================
// Foreign entity lookups via public model types
// =========================================================================

/// Look up a release by its external public UUID within an organization.
pub async fn release_by_public_id_and_org(
    db: &Database,
    release_public_id: &str,
    organization_id: i64,
) -> Result<Option<ReleaseSummary>, OrmError> {
    let found = crate::apps::releases::models::Release::objects()
        .filter(q!(public_id = release_public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await?;

    Ok(found.map(|r| ReleaseSummary {
        id: r.id,
        public_id: r.public_id,
        app_id: r.app_id.id,
        organization_id: r.organization_id,
        version: r.version,
        build_number: r.build_number,
        environment_id: r.environment_id,
        status: r.status,
        platforms: r.platforms,
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
        name: a.name,
        slug: a.slug,
    }))
}

/// List releases for an application within an organization, newest first.
pub async fn releases_for_app_and_org(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<ReleaseSummary>, OrmError> {
    let releases = crate::apps::releases::models::Release::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await?;

    Ok(releases
        .into_iter()
        .map(|r| ReleaseSummary {
            id: r.id,
            public_id: r.public_id,
            app_id: r.app_id.id,
            organization_id: r.organization_id,
            version: r.version,
            build_number: r.build_number,
            environment_id: r.environment_id,
            status: r.status,
            platforms: r.platforms,
        })
        .collect())
}

/// List environments for an application within an organization.
pub async fn environments_for_app_and_org(
    db: &Database,
    app_id: i64,
    organization_id: i64,
) -> Result<Vec<EnvironmentSummary>, OrmError> {
    let envs = crate::apps::environments::models::Environment::objects()
        .filter(q!(app_id = app_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("name")?
        .all(db)
        .await?;

    Ok(envs
        .into_iter()
        .map(|e| EnvironmentSummary {
            id: e.id,
            public_id: e.public_id,
            app_id: e.app_id,
            organization_id: e.organization_id,
            name: e.name,
            slug: e.slug,
        })
        .collect())
}
