//! Business logic, domain rules, and workflows for `builds`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    BuildCreateRequest, BuildLogsResponse, CompleteBuildRequest, StageUpdateRequest,
};
use super::errors::BuildError;
use super::models::{Build, BuildStage};
use super::repositories::{self, AppSummary, EnvironmentSummary, OrganizationSummary};
use crate::infra::queue::{Job, JobQueue};
use crate::infra::storage::{build_log_storage_key, ObjectStorage, DEFAULT_PRESIGNED_EXPIRY};

/// Emits an event to the events log.
///
/// Delegates to the `events` app's public service interface, which swallows and logs any
/// recording failure so that emitting an event never fails this app's own write.
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

/// Valid target platforms.
pub const VALID_PLATFORMS: &[&str] = &["android", "ios", "web", "all"];

/// Valid build profiles.
pub const VALID_BUILD_PROFILES: &[&str] = &["debug", "profile", "release"];

/// The ordered stages of a build execution.
pub const BUILD_STAGES: &[&str] = &[
    "checkout", "install", "resolve", "generate", "prebuild", "test", "analyze", "build", "upload",
];

/// Valid stage statuses.
pub const VALID_STAGE_STATUSES: &[&str] = &["pending", "running", "completed", "failed", "skipped"];

/// Returns `true` when `from -> to` is a legal build status transition.
///
/// The matrix is intentionally conservative: terminal states (`success`, `failed`,
/// `cancelled`) are absorbing, no transition ever returns to `pending`, and a build
/// may only enter `running` from `queued`. Cancellation is allowed from `pending`,
/// `queued`, and `running`; the `running` case is handled via a worker cancel signal
/// (see [`cancel_build`]), with the persisted `cancelled` status arriving from the
/// worker via [`complete_build`].
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("pending", "queued")
            | ("pending", "cancelled")
            | ("queued", "running")
            | ("queued", "cancelled")
            | ("queued", "failed")
            | ("running", "success")
            | ("running", "failed")
            | ("running", "cancelled")
    )
}

/// Returns `true` when `from -> to` is a legal build-stage status transition.
///
/// `pending` may advance to any active/terminal state; `running` may only finish.
/// Terminal stage states are absorbing.
pub fn can_stage_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("pending", "running")
            | ("pending", "completed")
            | ("pending", "failed")
            | ("pending", "skipped")
            | ("running", "completed")
            | ("running", "failed")
            | ("running", "skipped")
    )
}

/// Validate that a platform is one of `android`, `ios`, `web`, or `all`.
pub fn validate_platform(platform: &str) -> Result<(), BuildError> {
    if VALID_PLATFORMS.contains(&platform) {
        Ok(())
    } else {
        Err(BuildError::ValidationError(format!(
            "Invalid platform. Allowed values: {}.",
            VALID_PLATFORMS.join(", ")
        )))
    }
}

/// Validate that a build profile is one of `debug`, `profile`, or `release`.
pub fn validate_build_profile(profile: &str) -> Result<(), BuildError> {
    if VALID_BUILD_PROFILES.contains(&profile) {
        Ok(())
    } else {
        Err(BuildError::ValidationError(format!(
            "Invalid build profile. Allowed values: {}.",
            VALID_BUILD_PROFILES.join(", ")
        )))
    }
}

/// Validate that a stage name is one of the known build stages.
pub fn validate_stage_name(stage: &str) -> Result<(), BuildError> {
    if BUILD_STAGES.contains(&stage) {
        Ok(())
    } else {
        Err(BuildError::ValidationError(format!(
            "Invalid stage. Allowed values: {}.",
            BUILD_STAGES.join(", ")
        )))
    }
}

/// Validate that a stage status is one of `pending`, `running`, `completed`, `failed`,
/// or `skipped`.
pub fn validate_stage_status(status: &str) -> Result<(), BuildError> {
    if VALID_STAGE_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(BuildError::ValidationError(format!(
            "Invalid stage status. Allowed values: {}.",
            VALID_STAGE_STATUSES.join(", ")
        )))
    }
}

/// Create a new `Build` and queue its execution job.
///
/// Steps (per `apps/builds.md` §3):
/// 1. Resolve app and environment, verify they belong to the active organization and
///    to each other.
/// 2. Resolve git defaults from the app when not provided.
/// 3. Apply environment defaults for profile and versions.
/// 4. Insert the `Build` with `status = "pending"`.
/// 5. Create the full set of `BuildStage` rows.
/// 6. Emit `build.created`.
/// 7. Queue the build job via Redis `JobQueue`.
/// 8. Transition to `queued` and emit `build.queued`.
pub async fn create_build(
    db: &Database,
    organization_id: i64,
    user_id: Option<i64>,
    queue: &JobQueue,
    req: BuildCreateRequest,
) -> Result<
    (
        Build,
        Vec<BuildStage>,
        AppSummary,
        EnvironmentSummary,
        OrganizationSummary,
    ),
    BuildError,
> {
    // 1. Resolve app and environment.
    let app = repositories::app_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    let env =
        repositories::environment_by_public_id_and_org(db, &req.environment_id, organization_id)
            .await?
            .ok_or(BuildError::EnvironmentNotFound)?;

    if env.app_id != app.id {
        return Err(BuildError::EnvironmentNotFound);
    }

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(BuildError::OrganizationNotFound)?;

    // Billing gate (PHASES.md Phase 7): refuse the build only on a hard lock. A soft block or
    // warning still queues, so a free-tier org inside its grace period is nudged, not stopped.
    // ESTIMATED_BUILD_MINUTES is the projection charged against the monthly quota up front; the
    // real duration is metered on completion.
    const ESTIMATED_BUILD_MINUTES: i64 = 10;
    crate::apps::billing::services::ensure_build_allowed(
        db,
        organization_id,
        ESTIMATED_BUILD_MINUTES,
    )
    .await
    .map_err(|e| BuildError::BillingBlocked(e.to_string()))?;

    let project_public_id = repositories::project_public_id_by_id(db, app.project_id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    // 2. Resolve git defaults from the app when not provided.
    let git_branch = req
        .git_branch
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&app.default_branch)
        .to_string();

    let git_ref = req
        .git_ref
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&git_branch)
        .to_string();

    let git_commit = req
        .git_commit
        .as_deref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_default();

    // 3. Resolve platform and environment defaults for profile/versions.
    let platform = req.platform.trim().to_string();
    validate_platform(&platform)?;

    let build_profile = req
        .build_profile
        .as_deref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .unwrap_or(&env.build_profile)
        .to_string();
    validate_build_profile(&build_profile)?;

    let flutter_version = req
        .flutter_version
        .or_else(|| env.flutter_version.clone())
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_default();

    let dart_version = req
        .dart_version
        .or_else(|| env.dart_version.clone())
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_default();

    let bloom_version = req
        .bloom_version
        .or_else(|| env.bloom_version.clone())
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_default();

    let flavor = req
        .flavor
        .or_else(|| env.flavor.clone())
        .map(|f| f.trim().to_string())
        .filter(|f| !f.is_empty());

    // 4. Insert the Build with `status = "pending"`.
    let now = Utc::now();
    let build = Build {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: ForeignKey::new(app.id),
        organization_id,
        environment_id: ForeignKey::new(env.id),
        git_commit,
        git_branch,
        git_ref,
        status: "pending".to_string(),
        platform: platform.clone(),
        build_profile,
        flutter_version,
        dart_version,
        bloom_version,
        flavor,
        started_at: None,
        finished_at: None,
        logs_url: None,
        worker_id: None,
        metadata: "{}".to_string(),
        created_at: now,
        updated_at: now,
    };

    let saved_build = repositories::insert_build(db, build).await?;

    // 5. Create the full set of `BuildStage` rows.
    let mut stages = Vec::with_capacity(BUILD_STAGES.len());
    for stage_name in BUILD_STAGES {
        let stage = BuildStage {
            id: 0,
            build_id: ForeignKey::new(saved_build.id),
            stage: (*stage_name).to_string(),
            status: "pending".to_string(),
            started_at: None,
            finished_at: None,
            log_snippet: None,
            created_at: now,
        };
        let saved_stage = repositories::insert_buildstage(db, stage).await?;
        stages.push(saved_stage);
    }

    // 6. Emit build.created
    emit_event(
        db,
        "build.created",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        user_id,
        serde_json::json!({
            "build_id": saved_build.public_id,
            "app_id": app.public_id,
            "environment_id": env.public_id,
            "platform": platform,
        }),
    )
    .await;

    // 7. Queue the build job via Redis JobQueue.
    let job = Job::Build {
        build_id: saved_build.public_id.clone(),
        organization_id: org.public_id.clone(),
        project_id: project_public_id,
        app_id: app.public_id.clone(),
        environment_id: env.public_id.clone(),
        git_commit: saved_build.git_commit.clone(),
        platform: saved_build.platform.clone(),
        build_profile: saved_build.build_profile.clone(),
    };

    queue
        .push(job)
        .await
        .map_err(|e| BuildError::QueueError(e.to_string()))?;

    // 8. Transition to `queued` and emit build.queued.
    let mut queued = saved_build.clone();
    queued.status = "queued".to_string();
    queued.updated_at = Utc::now();
    repositories::update_build(db, &queued).await?;

    emit_event(
        db,
        "build.queued",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        user_id,
        serde_json::json!({ "build_id": queued.public_id }),
    )
    .await;

    Ok((queued, stages, app, env, org))
}

/// A build together with its ancestor public identifiers and stages, ready for wire
/// serialization. Named struct rather than a bare tuple so positional fields cannot be
/// swapped.
pub struct BuildDetail {
    /// The build record.
    pub build: Build,
    /// Ordered stages of the build.
    pub stages: Vec<BuildStage>,
    /// External public UUID of the parent app.
    pub app_public_id: String,
    /// External public UUID of the target environment.
    pub environment_public_id: String,
    /// External public UUID of the owning organization.
    pub organization_public_id: String,
}

/// Retrieve a build (with its stages) by public UUID within an organization.
pub async fn get_build(
    db: &Database,
    organization_id: i64,
    build_public_id: &str,
) -> Result<BuildDetail, BuildError> {
    let build = repositories::build_by_public_id_and_org(db, build_public_id, organization_id)
        .await?
        .ok_or(BuildError::BuildNotFound)?;

    let stages = repositories::buildstages_for_build(db, build.id).await?;

    let app_public_id = repositories::app_public_id_by_id(db, build.app_id.id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    let environment_public_id =
        repositories::environment_public_id_by_id(db, build.environment_id.id)
            .await?
            .ok_or(BuildError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(BuildError::OrganizationNotFound)?;

    Ok(BuildDetail {
        build,
        stages,
        app_public_id,
        environment_public_id,
        organization_public_id: org.public_id,
    })
}

/// List builds within an organization, optionally filtered by app or environment.
pub async fn list_builds(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
    environment_public_id: Option<&str>,
) -> Result<Vec<BuildDetail>, BuildError> {
    let builds = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(BuildError::AppNotFound)?;
        repositories::builds_for_app(db, app.id, organization_id).await?
    } else if let Some(env_pub_id) = environment_public_id {
        let env = repositories::environment_by_public_id_and_org(db, env_pub_id, organization_id)
            .await?
            .ok_or(BuildError::EnvironmentNotFound)?;
        repositories::builds_for_environment(db, env.id, organization_id).await?
    } else {
        repositories::builds_for_organization(db, organization_id).await?
    };

    let mut results = Vec::with_capacity(builds.len());
    for build in builds {
        let stages = repositories::buildstages_for_build(db, build.id).await?;

        let app_public_id = repositories::app_public_id_by_id(db, build.app_id.id)
            .await?
            .ok_or(BuildError::AppNotFound)?;

        let environment_public_id =
            repositories::environment_public_id_by_id(db, build.environment_id.id)
                .await?
                .ok_or(BuildError::EnvironmentNotFound)?;

        let org = repositories::organization_summary_by_id(db, organization_id)
            .await?
            .ok_or(BuildError::OrganizationNotFound)?;

        results.push(BuildDetail {
            build,
            stages,
            app_public_id,
            environment_public_id,
            organization_public_id: org.public_id,
        });
    }

    Ok(results)
}

/// Cancel a build (per `apps/builds.md` §3).
///
/// Only `pending` or `queued` builds are cancelled immediately. A `running` build is
/// not transitioned here: a cancel signal is sent to the worker, and the worker
/// reports the terminal `cancelled` status back via [`complete_build`].
pub async fn cancel_build(
    db: &Database,
    organization_id: i64,
    user_id: Option<i64>,
    build_public_id: &str,
) -> Result<BuildDetail, BuildError> {
    let build = repositories::build_by_public_id_and_org(db, build_public_id, organization_id)
        .await?
        .ok_or(BuildError::BuildNotFound)?;

    let updated = match build.status.as_str() {
        "pending" | "queued" => {
            let mut updated = build.clone();
            updated.status = "cancelled".to_string();
            updated.finished_at = Some(Utc::now());
            updated.updated_at = Utc::now();
            repositories::update_build(db, &updated).await?;

            emit_event(
                db,
                "build.cancelled",
                Some(organization_id),
                None,
                Some(updated.app_id.id),
                user_id,
                serde_json::json!({
                    "build_id": updated.public_id,
                    "cancelled_by": user_id,
                }),
            )
            .await;

            updated
        }
        "running" => {
            // The worker must observe the cancel request between stages and ack by
            // reporting `cancelled` via complete_build.
            emit_event(
                db,
                "build.cancelled",
                Some(organization_id),
                None,
                Some(build.app_id.id),
                user_id,
                serde_json::json!({
                    "build_id": build.public_id,
                    "cancelled_by": user_id,
                }),
            )
            .await;

            // TODO(spec): send a cancel signal to the worker (a Redis cancel key keyed
            // by the build public UUID) — `infra/queue.rs` exposes no cancel primitive
            // yet, so this is left for the phase that adds the worker protocol.

            build.clone()
        }
        _ => return Err(BuildError::InvalidStatus),
    };

    let stages = repositories::buildstages_for_build(db, updated.id).await?;

    let app_public_id = repositories::app_public_id_by_id(db, updated.app_id.id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    let environment_public_id =
        repositories::environment_public_id_by_id(db, updated.environment_id.id)
            .await?
            .ok_or(BuildError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(BuildError::OrganizationNotFound)?;

    Ok(BuildDetail {
        build: updated,
        stages,
        app_public_id,
        environment_public_id,
        organization_public_id: org.public_id,
    })
}

/// Report a stage update from a worker (internal endpoint).
///
/// Creates the stage row on first report, then validates subsequent transitions.
/// When a stage transitions to `running` and the build is still `queued`, the build is
/// advanced to `running` and stamped with `started_at`/`worker_id`.
pub async fn update_stage(
    db: &Database,
    build_public_id: &str,
    req: StageUpdateRequest,
) -> Result<(), BuildError> {
    let build = repositories::build_by_public_id(db, build_public_id)
        .await?
        .ok_or(BuildError::BuildNotFound)?;

    validate_stage_name(&req.stage)?;
    validate_stage_status(&req.status)?;

    let now = Utc::now();
    let existing = repositories::buildstage_by_build_and_stage(db, build.id, &req.stage).await?;

    // Captured for the `build.stage.completed` duration below: the moment this stage was
    // marked running, which for a same-call running->completed report is `now`.
    let stage_started_at;

    match existing {
        Some(mut stage) => {
            if !can_stage_transition(&stage.status, &req.status) {
                return Err(BuildError::InvalidStatus);
            }
            stage.status = req.status.clone();
            match req.status.as_str() {
                "running" => stage.started_at = Some(now),
                "completed" | "failed" | "skipped" => stage.finished_at = Some(now),
                _ => {}
            }
            if req.log_snippet.is_some() {
                stage.log_snippet = req.log_snippet.clone();
            }
            stage_started_at = stage.started_at;
            repositories::update_buildstage(db, &stage).await?;
        }
        None => {
            let stage = BuildStage {
                id: 0,
                build_id: ForeignKey::new(build.id),
                stage: req.stage.clone(),
                status: req.status.clone(),
                started_at: if req.status == "running" {
                    Some(now)
                } else {
                    None
                },
                finished_at: if matches!(req.status.as_str(), "completed" | "failed" | "skipped") {
                    Some(now)
                } else {
                    None
                },
                log_snippet: req.log_snippet.clone(),
                created_at: now,
            };
            stage_started_at = stage.started_at;
            repositories::insert_buildstage(db, stage).await?;
        }
    };

    // Advance the build when the first stage begins.
    if req.status == "running" && build.status == "queued" {
        let mut updated = build.clone();
        updated.status = "running".to_string();
        updated.started_at = Some(now);
        if let Some(worker_id) = req.worker_id.as_ref().filter(|w| !w.trim().is_empty()) {
            updated.worker_id = Some(worker_id.clone());
        }
        updated.updated_at = now;
        repositories::update_build(db, &updated).await?;

        emit_event(
            db,
            "build.started",
            Some(build.organization_id),
            None,
            Some(build.app_id.id),
            None,
            serde_json::json!({
                "build_id": build.public_id,
                "worker_id": updated.worker_id,
            }),
        )
        .await;
    }

    // Stage events per events.md. `duration_ms` is measured from the stage's own
    // `started_at`; a stage that reached a terminal status without ever being marked
    // running has no meaningful duration, so the key is omitted rather than reported as 0.
    let stage_event = match req.status.as_str() {
        "running" => Some((
            "build.stage.started",
            serde_json::json!({ "build_id": build.public_id, "stage": req.stage }),
        )),
        "completed" => {
            let mut payload =
                serde_json::json!({ "build_id": build.public_id, "stage": req.stage });
            if let Some(duration_ms) = stage_started_at
                .map(|started| (now - started).num_milliseconds())
                .filter(|ms| *ms >= 0)
            {
                payload["duration_ms"] = serde_json::json!(duration_ms);
            }
            Some(("build.stage.completed", payload))
        }
        "failed" => Some((
            "build.stage.failed",
            serde_json::json!({
                "build_id": build.public_id,
                "stage": req.stage,
                "reason": req.log_snippet,
            }),
        )),
        _ => None,
    };

    if let Some((event_type, payload)) = stage_event {
        emit_event(
            db,
            event_type,
            Some(build.organization_id),
            None,
            Some(build.app_id.id),
            None,
            payload,
        )
        .await;
    }

    Ok(())
}

/// Mark a build complete/failed from a worker (internal endpoint).
///
/// Only terminal transitions are accepted; the build's status is validated against
/// the conservative [`can_transition`] matrix.
pub async fn complete_build(
    db: &Database,
    build_public_id: &str,
    req: CompleteBuildRequest,
) -> Result<Build, BuildError> {
    let build = repositories::build_by_public_id(db, build_public_id)
        .await?
        .ok_or(BuildError::BuildNotFound)?;

    let target = req.status.trim().to_string();
    if !can_transition(&build.status, &target) {
        return Err(BuildError::InvalidStatus);
    }
    if !matches!(target.as_str(), "success" | "failed" | "cancelled") {
        return Err(BuildError::ValidationError(format!(
            "CompleteBuildRequest.status must be success, failed, or cancelled; got {target}."
        )));
    }

    let mut updated = build.clone();
    updated.status = target.clone();
    updated.finished_at = Some(Utc::now());
    updated.updated_at = Utc::now();

    if let Some(logs_url) = req.logs_url.as_ref().filter(|s| !s.trim().is_empty()) {
        updated.logs_url = Some(logs_url.clone());
    }
    if let Some(metadata) = req.metadata.as_ref().filter(|s| !s.trim().is_empty()) {
        updated.metadata = metadata.clone();
    }

    repositories::update_build(db, &updated).await?;

    // Terminal build events per events.md. This path is the worker reporting back, so the
    // actor is the system (`actor_id: None`) rather than a user.
    let (event_type, payload) = match target.as_str() {
        "success" => (
            "build.completed",
            serde_json::json!({ "build_id": updated.public_id, "status": "success" }),
        ),
        "failed" => (
            "build.failed",
            serde_json::json!({ "build_id": updated.public_id, "reason": req.reason }),
        ),
        _ => (
            "build.cancelled",
            serde_json::json!({ "build_id": updated.public_id, "cancelled_by": "system" }),
        ),
    };

    emit_event(
        db,
        event_type,
        Some(updated.organization_id),
        None,
        Some(updated.app_id.id),
        None,
        payload,
    )
    .await;

    Ok(updated)
}

/// Generate a short-lived presigned URL for a build's log object.
///
/// The storage key is derived from the canonical hierarchy
/// `orgs/{org}/projects/{project}/apps/{app}/builds/{build}/logs/build.log`
/// (see [`build_log_storage_key`]); logs stay private and are never served as bare
/// bucket URLs.
pub async fn build_logs(
    db: &Database,
    storage: &dyn ObjectStorage,
    organization_id: i64,
    build_public_id: &str,
) -> Result<BuildLogsResponse, BuildError> {
    let build = repositories::build_by_public_id_and_org(db, build_public_id, organization_id)
        .await?
        .ok_or(BuildError::BuildNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(BuildError::OrganizationNotFound)?;

    let app = repositories::app_summary_by_id(db, build.app_id.id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    let project_public_id = repositories::project_public_id_by_id(db, app.project_id)
        .await?
        .ok_or(BuildError::AppNotFound)?;

    let key = build_log_storage_key(
        &org.public_id,
        &project_public_id,
        &app.public_id,
        &build.public_id,
    );

    let url = storage
        .presigned_url(&key, DEFAULT_PRESIGNED_EXPIRY)
        .await?;

    Ok(BuildLogsResponse {
        url,
        expires_in_secs: DEFAULT_PRESIGNED_EXPIRY.as_secs() as i64,
    })
}
