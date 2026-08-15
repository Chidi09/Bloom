//! Business logic, domain rules, state transitions, and background queueing for `deployments`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::DeploymentCreateRequest;
use super::errors::DeploymentError;
use super::models::Deployment;
use super::permissions::OrganizationRole;
use super::repositories;
use crate::infra::queue::{Job, JobQueue};

/// Valid platform identifiers for deployments.
pub const VALID_PLATFORMS: &[&str] = &["ios", "android", "web"];

/// Valid target destinations for deployments.
pub const VALID_TARGETS: &[&str] = &[
    "testflight",
    "app_store",
    "internal",
    "closed",
    "open",
    "production",
    "preview",
];

/// Valid deployment lifecycle statuses.
pub const VALID_STATUSES: &[&str] = &[
    "pending",
    "queued",
    "running",
    "processing",
    "ready",
    "live",
    "failed",
    "rolled_back",
];

/// Detailed deployment with resolved related public UUIDs for wire serialization.
#[derive(Debug, Clone)]
pub struct DeploymentDetail {
    /// The underlying deployment record.
    pub deployment: Deployment,
    /// External public UUID of the optional release.
    pub release_public_id: Option<String>,
    /// External public UUID of the optional artifact.
    pub artifact_public_id: Option<String>,
    /// External public UUID of the target environment.
    pub environment_public_id: String,
    /// External public UUID of the tenant organization.
    pub organization_public_id: String,
    /// External public identifier of the creator user.
    pub created_by_public_id: String,
}

/// Returns `true` when `from -> to` is a legal deployment status transition.
///
/// # Transition Matrix Rationale
/// - `pending`: Initial state upon creation. Can advance to `queued` (when job is pushed to Redis queue),
///   `running` (claimed by worker directly), or `failed` (if queueing or pre-flight fails).
/// - `queued`: In the queue waiting for a worker. Can advance to `running` (worker claims job) or `failed`.
/// - `running`: Worker is actively preparing/uploading the deployment. Can advance to `processing`
///   (platform acknowledged upload), `ready` (e.g. TestFlight instant availability or direct completion),
///   `live` (e.g. web/mobile immediate publish), or `failed`.
/// - `processing`: Vendor platform (App Store Connect / Google Play) is processing the uploaded build.
///   Can advance to `ready` (TestFlight build processing finished and ready for testing), `live` (Google Play release live),
///   or `failed` (validation failure or processing error).
/// - `ready`: Terminal absorbing state for testing deployments (e.g. TestFlight ready). Can transition to `rolled_back` on manual rollback.
/// - `live`: Terminal absorbing state for production / active deployments. Can transition to `rolled_back` on manual rollback.
/// - `failed`: Terminal absorbing state. No transitions allowed out.
/// - `rolled_back`: Terminal absorbing state. No transitions allowed out.
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("pending", "queued")
            | ("pending", "running")
            | ("pending", "failed")
            | ("queued", "running")
            | ("queued", "failed")
            | ("running", "processing")
            | ("running", "ready")
            | ("running", "live")
            | ("running", "failed")
            | ("processing", "ready")
            | ("processing", "live")
            | ("processing", "failed")
            | ("ready", "rolled_back")
            | ("live", "rolled_back")
    )
}

/// Validate platform and target combination.
///
/// Rules:
/// - iOS targets: `testflight`, `app_store`
/// - Android targets: `internal`, `closed`, `open`, `production`
/// - Web targets: `preview`, `production`
pub fn validate_platform_and_target(platform: &str, target: &str) -> Result<(), DeploymentError> {
    if !VALID_PLATFORMS.contains(&platform) {
        return Err(DeploymentError::InvalidPlatform(platform.to_string()));
    }
    if !VALID_TARGETS.contains(&target) {
        return Err(DeploymentError::InvalidTarget(target.to_string()));
    }

    let is_valid = match platform {
        "ios" => matches!(target, "testflight" | "app_store"),
        "android" => matches!(target, "internal" | "closed" | "open" | "production"),
        "web" => matches!(target, "preview" | "production"),
        _ => false,
    };

    if !is_valid {
        return Err(DeploymentError::IncompatiblePlatformAndTarget {
            platform: platform.to_string(),
            target: target.to_string(),
        });
    }

    Ok(())
}

/// Checks whether a target represents a production target requiring ReleaseManager permission and release approval.
pub fn is_production_target(target: &str) -> bool {
    matches!(target, "production" | "app_store")
}

/// Emits an event to the events log.
///
/// Delegates to the `events` app's public service interface, which swallows and logs failures.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Create and enqueue a new deployment.
///
/// # Business Logic & Exit Gates:
/// 1. Validate platform/target compatibility.
/// 2. Require either `release_id` or `artifact_id`.
/// 3. Resolve environment and verify it belongs to organization.
/// 4. Resolve release or artifact, and verify organization ownership.
/// 5. Enforce approval rules: production and app_store targets require an approved release.
/// 6. Insert `Deployment` with `status = "pending"`.
/// 7. Push deploy job to `JobQueue` via Redis streams. If queue is available, transitions to `"queued"`.
/// 8. Emit `deployment.created` event.
pub async fn create_deployment(
    db: &Database,
    queue: Option<&JobQueue>,
    organization_id: i64,
    user_id: i64,
    _user_role: OrganizationRole,
    req: DeploymentCreateRequest,
    // See `builds::services::create_build`: set only by the workflow engine, never by a client.
    workflow_run_step_id: Option<i64>,
) -> Result<DeploymentDetail, DeploymentError> {
    let platform = req.platform.trim().to_ascii_lowercase();
    let target = req.target.trim().to_ascii_lowercase();
    validate_platform_and_target(&platform, &target)?;

    if req.release_id.is_none() && req.artifact_id.is_none() {
        return Err(DeploymentError::MissingReleaseOrArtifact);
    }

    // 1. Resolve organization.
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(DeploymentError::OrganizationNotFound)?;

    // Billing gate (PHASES.md Phase 7): the target decides which plan feature flag applies.
    // Only a hard lock refuses; soft blocks and warnings proceed.
    crate::apps::billing::services::ensure_deployment_allowed(db, organization_id, &target)
        .await
        .map_err(|e| DeploymentError::BillingBlocked(e.to_string()))?;

    // 2. Resolve environment.
    let env = repositories::environment_summary_by_public_id_and_org(
        db,
        &req.environment_id,
        organization_id,
    )
    .await?
    .ok_or(DeploymentError::EnvironmentNotFound)?;

    // 3. Resolve optional release and artifact.
    let release_summary = if let Some(ref rel_id) = req.release_id {
        let r = repositories::release_summary_by_public_id_and_org(db, rel_id, organization_id)
            .await?
            .ok_or(DeploymentError::ReleaseNotFound)?;
        Some(r)
    } else {
        None
    };

    let artifact_summary = if let Some(ref art_id) = req.artifact_id {
        let a = repositories::artifact_summary_by_public_id_and_org(db, art_id, organization_id)
            .await?
            .ok_or(DeploymentError::ArtifactNotFound)?;
        Some(a)
    } else if let Some(ref rel) = release_summary {
        // If artifact not explicitly specified, resolve primary artifact from the release
        let artifact_ids: Vec<String> = serde_json::from_str(&rel.artifacts).unwrap_or_default();
        let mut matching_artifact = None;
        for art_pub_id in &artifact_ids {
            if let Some(art) =
                repositories::artifact_summary_by_public_id_and_org(db, art_pub_id, organization_id)
                    .await?
            {
                if art.platform == platform {
                    matching_artifact = Some(art);
                    break;
                }
            }
        }
        matching_artifact
    } else {
        None
    };

    // 4. Enforce approval rules:
    // Production targets (`production`, `app_store`) require an approved release (PHASES.md Phase 5 exit gate).
    if is_production_target(&target) {
        match release_summary.as_ref() {
            Some(rel)
                if rel.status == "approved"
                    || rel.status == "rolling_out"
                    || rel.status == "released" => {}
            _ => return Err(DeploymentError::UnapprovedRelease),
        }
    }

    // 5. Build Deployment record.
    let deployment_public_id = Uuid::new_v4().to_string();
    let now = Utc::now();
    let deployment = Deployment {
        id: 0,
        public_id: deployment_public_id.clone(),
        workflow_run_step_id,
        release_id: release_summary.as_ref().map(|r| r.id),
        artifact_id: artifact_summary.as_ref().map(|a| a.id),
        environment_id: ForeignKey::new(env.id),
        organization_id,
        platform: platform.clone(),
        target: target.clone(),
        status: "pending".to_string(),
        external_id: None,
        external_url: None,
        error_message: None,
        started_at: None,
        finished_at: None,
        created_by_id: user_id,
        created_at: now,
        updated_at: now,
    };

    let mut saved = repositories::insert_deployment(db, deployment).await?;

    // 6. Enqueue deploy job via Redis if queue is provided.
    let artifact_pub_id_str = artifact_summary
        .as_ref()
        .map(|a| a.public_id.clone())
        .unwrap_or_default();

    let job = Job::Deploy {
        deployment_id: saved.public_id.clone(),
        organization_id: org.public_id.clone(),
        release_id: release_summary.as_ref().map(|r| r.public_id.clone()),
        artifact_id: artifact_pub_id_str.clone(),
        platform: saved.platform.clone(),
        target: saved.target.clone(),
    };

    if let Some(q) = queue {
        match q.push(job).await {
            Ok(_) => {
                if can_transition(&saved.status, "queued") {
                    saved.status = "queued".to_string();
                    saved.updated_at = Utc::now();
                    repositories::update_deployment(db, &saved).await?;
                }
            }
            Err(e) => {
                eprintln!(
                    "Failed to enqueue deployment job for {}: {e}",
                    saved.public_id
                );
            }
        }
    }

    // 7. Emit `deployment.created` event per events.md.
    emit_event(
        db,
        "deployment.created",
        Some(organization_id),
        None,
        Some(env.app_id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": saved.public_id,
            "release_id": release_summary.as_ref().map(|r| r.public_id.clone()),
            "platform": saved.platform,
            "target": saved.target,
        }),
    )
    .await;

    let user_pub_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    Ok(DeploymentDetail {
        deployment: saved,
        release_public_id: release_summary.map(|r| r.public_id),
        artifact_public_id: artifact_summary.map(|a| a.public_id),
        environment_public_id: env.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// Worker endpoint to update status and vendor diagnostics of a deployment.
///
/// Emits appropriate events according to target status:
/// - `running` -> `deployment.started`
/// - `processing` -> `deployment.processing` (and `testflight.processing` / `google_play.processing`)
/// - `ready` / `live` -> `deployment.completed` (and `testflight.ready` / `google_play.live`)
/// - `failed` -> `deployment.failed`
pub async fn update_deployment_status(
    db: &Database,
    organization_id: i64,
    deployment_public_id: &str,
    new_status: &str,
    external_id: Option<String>,
    external_url: Option<String>,
    error_message: Option<String>,
) -> Result<DeploymentDetail, DeploymentError> {
    let mut deployment =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(DeploymentError::DeploymentNotFound)?;

    if !can_transition(&deployment.status, new_status) {
        return Err(DeploymentError::InvalidStatus(format!(
            "Cannot transition deployment from '{}' to '{}'",
            deployment.status, new_status
        )));
    }

    let now = Utc::now();
    deployment.status = new_status.to_string();
    deployment.updated_at = now;

    if external_id.is_some() {
        deployment.external_id = external_id.clone();
    }
    if external_url.is_some() {
        deployment.external_url = external_url.clone();
    }
    if error_message.is_some() {
        deployment.error_message = error_message.clone();
    }

    if new_status == "running" && deployment.started_at.is_none() {
        deployment.started_at = Some(now);
    }
    if matches!(new_status, "ready" | "live" | "failed" | "rolled_back")
        && deployment.finished_at.is_none()
    {
        deployment.finished_at = Some(now);
    }

    repositories::update_deployment(db, &deployment).await?;

    let env = repositories::environment_summary_by_id(db, deployment.environment_id.id)
        .await?
        .ok_or(DeploymentError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(DeploymentError::OrganizationNotFound)?;

    let release_summary = match deployment.release_id {
        Some(rel_id) => repositories::release_summary_by_id(db, rel_id).await?,
        None => None,
    };

    let artifact_summary = match deployment.artifact_id {
        Some(art_id) => repositories::artifact_summary_by_id(db, art_id).await?,
        None => None,
    };

    let user_pub_id = repositories::user_public_id_by_id(db, deployment.created_by_id)
        .await?
        .unwrap_or_else(|| deployment.created_by_id.to_string());

    // Emit events according to status
    match new_status {
        "running" => {
            emit_event(
                db,
                "deployment.started",
                Some(organization_id),
                None,
                Some(env.app_id),
                None, // system actor
                serde_json::json!({
                    "deployment_id": deployment.public_id,
                    "worker_id": external_id.as_deref().unwrap_or("worker"),
                }),
            )
            .await;
        }
        "processing" => {
            emit_event(
                db,
                "deployment.processing",
                Some(organization_id),
                None,
                Some(env.app_id),
                None,
                serde_json::json!({
                    "deployment_id": deployment.public_id,
                    "external_id": deployment.external_id,
                    "external_url": deployment.external_url,
                }),
            )
            .await;

            if deployment.platform == "ios" {
                emit_event(
                    db,
                    "testflight.processing",
                    Some(organization_id),
                    None,
                    Some(env.app_id),
                    None,
                    serde_json::json!({
                        "deployment_id": deployment.public_id,
                        "build_id": deployment.external_id,
                    }),
                )
                .await;
            } else if deployment.platform == "android" {
                emit_event(
                    db,
                    "google_play.processing",
                    Some(organization_id),
                    None,
                    Some(env.app_id),
                    None,
                    serde_json::json!({
                        "deployment_id": deployment.public_id,
                        "version_code": deployment.external_id,
                    }),
                )
                .await;
            }
        }
        "ready" => {
            emit_event(
                db,
                "deployment.completed",
                Some(organization_id),
                None,
                Some(env.app_id),
                None,
                serde_json::json!({
                    "deployment_id": deployment.public_id,
                    "status": "ready",
                }),
            )
            .await;

            if deployment.platform == "ios" {
                emit_event(
                    db,
                    "testflight.ready",
                    Some(organization_id),
                    None,
                    Some(env.app_id),
                    None,
                    serde_json::json!({
                        "deployment_id": deployment.public_id,
                        "build_id": deployment.external_id,
                    }),
                )
                .await;
            }
        }
        "live" => {
            emit_event(
                db,
                "deployment.completed",
                Some(organization_id),
                None,
                Some(env.app_id),
                None,
                serde_json::json!({
                    "deployment_id": deployment.public_id,
                    "status": "live",
                }),
            )
            .await;

            if deployment.platform == "android" {
                emit_event(
                    db,
                    "google_play.live",
                    Some(organization_id),
                    None,
                    Some(env.app_id),
                    None,
                    serde_json::json!({
                        "deployment_id": deployment.public_id,
                        "version_code": deployment.external_id,
                        "track": deployment.target,
                    }),
                )
                .await;
            }
        }
        "failed" => {
            emit_event(
                db,
                "deployment.failed",
                Some(organization_id),
                None,
                Some(env.app_id),
                None,
                serde_json::json!({
                    "deployment_id": deployment.public_id,
                    "reason": deployment.error_message.as_deref().unwrap_or("Unknown failure"),
                }),
            )
            .await;
        }
        _ => {}
    }

    Ok(DeploymentDetail {
        deployment,
        release_public_id: release_summary.map(|r| r.public_id),
        artifact_public_id: artifact_summary.map(|a| a.public_id),
        environment_public_id: env.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// Roll back a deployment.
///
/// Marks `rolled_back` and emits `deployment.rolled_back`.
pub async fn rollback_deployment(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    deployment_public_id: &str,
) -> Result<DeploymentDetail, DeploymentError> {
    let mut deployment =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(DeploymentError::DeploymentNotFound)?;

    if is_production_target(&deployment.target) && user_role < OrganizationRole::ReleaseManager {
        return Err(DeploymentError::Forbidden);
    }
    if !is_production_target(&deployment.target) && user_role < OrganizationRole::Developer {
        return Err(DeploymentError::Forbidden);
    }

    if !can_transition(&deployment.status, "rolled_back") {
        return Err(DeploymentError::InvalidStatus(format!(
            "Cannot rollback deployment in status '{}'",
            deployment.status
        )));
    }

    let now = Utc::now();
    deployment.status = "rolled_back".to_string();
    deployment.finished_at = Some(now);
    deployment.updated_at = now;
    repositories::update_deployment(db, &deployment).await?;

    let env = repositories::environment_summary_by_id(db, deployment.environment_id.id)
        .await?
        .ok_or(DeploymentError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(DeploymentError::OrganizationNotFound)?;

    let release_summary = match deployment.release_id {
        Some(rel_id) => repositories::release_summary_by_id(db, rel_id).await?,
        None => None,
    };

    let artifact_summary = match deployment.artifact_id {
        Some(art_id) => repositories::artifact_summary_by_id(db, art_id).await?,
        None => None,
    };

    let user_pub_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    // Emit `deployment.rolled_back` event per events.md
    emit_event(
        db,
        "deployment.rolled_back",
        Some(organization_id),
        None,
        Some(env.app_id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": deployment.public_id,
        }),
    )
    .await;

    Ok(DeploymentDetail {
        deployment,
        release_public_id: release_summary.map(|r| r.public_id),
        artifact_public_id: artifact_summary.map(|a| a.public_id),
        environment_public_id: env.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// Retrieve a deployment by public UUID within an organization.
pub async fn get_deployment(
    db: &Database,
    organization_id: i64,
    deployment_public_id: &str,
) -> Result<DeploymentDetail, DeploymentError> {
    let deployment =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(DeploymentError::DeploymentNotFound)?;

    let env = repositories::environment_summary_by_id(db, deployment.environment_id.id)
        .await?
        .ok_or(DeploymentError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(DeploymentError::OrganizationNotFound)?;

    let release_summary = match deployment.release_id {
        Some(rel_id) => repositories::release_summary_by_id(db, rel_id).await?,
        None => None,
    };

    let artifact_summary = match deployment.artifact_id {
        Some(art_id) => repositories::artifact_summary_by_id(db, art_id).await?,
        None => None,
    };

    let user_pub_id = repositories::user_public_id_by_id(db, deployment.created_by_id)
        .await?
        .unwrap_or_else(|| deployment.created_by_id.to_string());

    Ok(DeploymentDetail {
        deployment,
        release_public_id: release_summary.map(|r| r.public_id),
        artifact_public_id: artifact_summary.map(|a| a.public_id),
        environment_public_id: env.public_id,
        organization_public_id: org.public_id,
        created_by_public_id: user_pub_id,
    })
}

/// List deployments in an organization, optionally filtered by release, environment, platform, target, or status.
pub async fn list_deployments(
    db: &Database,
    organization_id: i64,
    release_public_id: Option<&str>,
    environment_public_id: Option<&str>,
    platform_filter: Option<&str>,
    target_filter: Option<&str>,
    status_filter: Option<&str>,
) -> Result<Vec<DeploymentDetail>, DeploymentError> {
    let deployments = if let Some(rel_pub_id) = release_public_id {
        if let Some(rel) =
            repositories::release_summary_by_public_id_and_org(db, rel_pub_id, organization_id)
                .await?
        {
            repositories::deployments_for_release(db, rel.id, organization_id).await?
        } else {
            return Ok(Vec::new());
        }
    } else if let Some(env_pub_id) = environment_public_id {
        if let Some(env) =
            repositories::environment_summary_by_public_id_and_org(db, env_pub_id, organization_id)
                .await?
        {
            repositories::deployments_for_environment(db, env.id, organization_id).await?
        } else {
            return Ok(Vec::new());
        }
    } else {
        repositories::deployments_for_organization(db, organization_id).await?
    };

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(DeploymentError::OrganizationNotFound)?;

    let mut results = Vec::new();
    for d in deployments {
        if let Some(p) = platform_filter {
            if d.platform != p {
                continue;
            }
        }
        if let Some(t) = target_filter {
            if d.target != t {
                continue;
            }
        }
        if let Some(s) = status_filter {
            if d.status != s {
                continue;
            }
        }

        let env = repositories::environment_summary_by_id(db, d.environment_id.id)
            .await?
            .ok_or(DeploymentError::EnvironmentNotFound)?;

        let release_summary = match d.release_id {
            Some(rel_id) => repositories::release_summary_by_id(db, rel_id).await?,
            None => None,
        };

        let artifact_summary = match d.artifact_id {
            Some(art_id) => repositories::artifact_summary_by_id(db, art_id).await?,
            None => None,
        };

        let user_pub_id = repositories::user_public_id_by_id(db, d.created_by_id)
            .await?
            .unwrap_or_else(|| d.created_by_id.to_string());

        results.push(DeploymentDetail {
            deployment: d,
            release_public_id: release_summary.map(|r| r.public_id),
            artifact_public_id: artifact_summary.map(|a| a.public_id),
            environment_public_id: env.public_id,
            organization_public_id: org.public_id.clone(),
            created_by_public_id: user_pub_id,
        });
    }

    Ok(results)
}
