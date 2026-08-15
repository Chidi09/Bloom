//! Business logic and service layer operations for the `observability` app.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;

use super::contracts::{AppStatusResponse, EnvironmentStatus, ReleaseHealthResponse};
use super::errors::ObservabilityError;
use super::models::{PlatformMetric, ReleaseHealthSnapshot};
use super::{repositories, serializers};

/// The platform-reported figures making up one health snapshot.
///
/// Grouped into a struct rather than passed positionally: `sessions`, `crashes`, and
/// `active_users` are all `Option<i64>`, so a positional list silently tolerates a swapped
/// pair — which would compute a crash-free rate from the wrong numerator.
#[derive(Debug, Clone, Default)]
pub struct HealthSnapshotInput {
    /// Crash-free session rate, when the platform reports one directly.
    pub crash_free_rate: Option<f64>,
    /// Total sessions reported.
    pub sessions: Option<i64>,
    /// Total crashes reported.
    pub crashes: Option<i64>,
    /// Active users reported.
    pub active_users: Option<i64>,
    /// Raw platform payload, stored as JSON text.
    pub metric_data: serde_json::Value,
}

/// Store a platform-reported health snapshot for a release.
///
/// If `crash_free_rate` is not explicitly provided, it is automatically derived
/// from `sessions` and `crashes` if valid session data is present.
pub async fn capture_health_snapshot(
    db: &Database,
    release_id: i64,
    platform: &str,
    target: &str,
    input: HealthSnapshotInput,
) -> Result<ReleaseHealthSnapshot, ObservabilityError> {
    let HealthSnapshotInput {
        crash_free_rate,
        sessions,
        crashes,
        active_users,
        metric_data,
    } = input;

    let computed_rate =
        crash_free_rate.or_else(|| serializers::compute_crash_free_rate(sessions, crashes));

    let snapshot = ReleaseHealthSnapshot {
        id: 0,
        release_id: ForeignKey::new(release_id),
        platform: platform.to_string(),
        target: target.to_string(),
        crash_free_rate: computed_rate,
        sessions,
        crashes,
        active_users,
        metric_data: metric_data.to_string(),
        captured_at: Utc::now(),
    };

    repositories::insert_snapshot(db, snapshot)
        .await
        .map_err(Into::into)
}

/// Store a single platform metric measurement for a deployment.
pub async fn record_platform_metric(
    db: &Database,
    deployment_id: i64,
    metric_type: &str,
    value: i64,
) -> Result<PlatformMetric, ObservabilityError> {
    let metric = PlatformMetric {
        id: 0,
        deployment_id: djangors_orm::ForeignKey::new(deployment_id),
        metric_type: metric_type.to_string(),
        value,
        captured_at: Utc::now(),
    };

    repositories::insert_platform_metric(db, metric)
        .await
        .map_err(Into::into)
}

/// Retrieve aggregated release health and platform metrics for a given release.
///
/// Scoped to the caller's organization. If the release exists but has no metrics reported yet,
/// returns a well-formed empty response with `overall_crash_free_rate: None` and an empty platform list.
pub async fn get_release_health(
    db: &Database,
    release_public_id: &str,
    organization_id: i64,
) -> Result<ReleaseHealthResponse, ObservabilityError> {
    let release =
        repositories::release_by_public_id_and_org(db, release_public_id, organization_id)
            .await?
            .ok_or(ObservabilityError::ReleaseNotFound)?;

    let snapshots = repositories::snapshots_for_release(db, release.id).await?;

    Ok(serializers::serialize_release_health(
        &release.public_id,
        &snapshots,
    ))
}

/// Retrieve current live deployment and health status for an application across environments.
///
/// Scoped to the caller's organization. When no releases or metrics are recorded yet,
/// returns a well-formed empty response with `environments: []`.
pub async fn get_app_status(
    db: &Database,
    app_public_id: &str,
    organization_id: i64,
) -> Result<AppStatusResponse, ObservabilityError> {
    let app = repositories::app_by_public_id_and_org(db, app_public_id, organization_id)
        .await?
        .ok_or(ObservabilityError::AppNotFound)?;

    let environments =
        repositories::environments_for_app_and_org(db, app.id, organization_id).await?;
    let releases = repositories::releases_for_app_and_org(db, app.id, organization_id).await?;

    if environments.is_empty() && releases.is_empty() {
        return Ok(AppStatusResponse {
            app_id: app.public_id,
            environments: Vec::new(),
        });
    }

    let mut environment_statuses = Vec::new();

    // Map each environment to its latest release (if any) and aggregate health
    for env in &environments {
        let env_release = releases.iter().find(|r| r.environment_id == Some(env.id));

        if let Some(rel) = env_release {
            let snapshots = repositories::snapshots_for_release(db, rel.id).await?;
            let health = serializers::serialize_release_health(&rel.public_id, &snapshots);

            let platforms: Vec<String> = serde_json::from_str(&rel.platforms).unwrap_or_default();
            if platforms.is_empty() {
                environment_statuses.push(EnvironmentStatus {
                    environment: env.slug.clone(),
                    platform: "all".to_string(),
                    release_id: Some(rel.public_id.clone()),
                    version: Some(rel.version.clone()),
                    build_number: Some(rel.build_number),
                    status: rel.status.clone(),
                    crash_free_rate: health.overall_crash_free_rate,
                });
            } else {
                for platform in platforms {
                    let plat_health = health.platforms.iter().find(|p| p.platform == platform);
                    let rate = plat_health
                        .and_then(|p| p.crash_free_rate)
                        .or(health.overall_crash_free_rate);

                    environment_statuses.push(EnvironmentStatus {
                        environment: env.slug.clone(),
                        platform,
                        release_id: Some(rel.public_id.clone()),
                        version: Some(rel.version.clone()),
                        build_number: Some(rel.build_number),
                        status: rel.status.clone(),
                        crash_free_rate: rate,
                    });
                }
            }
        } else {
            environment_statuses.push(EnvironmentStatus {
                environment: env.slug.clone(),
                platform: "all".to_string(),
                release_id: None,
                version: None,
                build_number: None,
                status: "no_release".to_string(),
                crash_free_rate: None,
            });
        }
    }

    // If there were no explicit environments configured, summarize the latest general release
    if environments.is_empty() {
        if let Some(latest_rel) = releases.first() {
            let snapshots = repositories::snapshots_for_release(db, latest_rel.id).await?;
            let health = serializers::serialize_release_health(&latest_rel.public_id, &snapshots);

            environment_statuses.push(EnvironmentStatus {
                environment: "default".to_string(),
                platform: "all".to_string(),
                release_id: Some(latest_rel.public_id.clone()),
                version: Some(latest_rel.version.clone()),
                build_number: Some(latest_rel.build_number),
                status: latest_rel.status.clone(),
                crash_free_rate: health.overall_crash_free_rate,
            });
        }
    }

    Ok(AppStatusResponse {
        app_id: app.public_id,
        environments: environment_statuses,
    })
}
