//! Build worker skeleton implementing the Flutter/Dart build execution protocol.
//!
//! # Architecture & Scope
//!
//! The build worker claims pending `Job::Build` entries from the `JobQueue`, drives the
//! 9-stage build pipeline, reports stage transitions through `crate::apps::builds::services::update_stage`,
//! stores artifacts via `crate::apps::artifacts::services::register_artifact`, uploads build
//! logs, and completes the build via `crate::apps::builds::services::complete_build`.
//!
//! # Flutter Toolchain Execution
//!
//! Execution of the actual Flutter/Dart toolchain is deferred per `PHASES.md` Phase 3 Deliverable 5.
//! The worker skeleton sets up the complete, correct claim/heartbeat/report/upload/finish protocol.
//!
//! # Total Ack/Fail Contract
//!
//! Every claimed build job MUST explicitly terminate in:
//! - `queue.ack(stream_id)` on successful execution and completion reporting.
//! - `queue.fail(stream_id, &reason)` if any stage fails or an unrecoverable error occurs,
//!   recording the failure diagnostics and updating the build record to `failed`.

use bytes::Bytes;
use djangors_db::Database;
use std::fmt;

use crate::apps::artifacts::contracts::ArtifactRegisterRequest;
use crate::apps::artifacts::services as artifact_services;
use crate::apps::builds::contracts::{CompleteBuildRequest, StageUpdateRequest};
use crate::apps::builds::services as build_services;
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};
use crate::infra::storage::{
    artifact_storage_key, build_log_storage_key, ObjectStorage, StorageError,
};

/// The canonical ordered stages executed during a build.
pub const BUILD_STAGES: &[&str] = &[
    "checkout", "install", "resolve", "generate", "prebuild", "test", "analyze", "build", "upload",
];

/// Errors arising during build worker execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuildWorkerError {
    /// Queue interaction error.
    Queue(String),
    /// Storage error during log or artifact upload.
    Storage(String),
    /// Domain build service error.
    BuildService(String),
    /// Domain artifact service error.
    ArtifactService(String),
    /// Unexpected job variant passed to build worker.
    InvalidJobVariant(String),
    /// Stage execution failure.
    StageFailed {
        /// The stage that failed.
        stage: String,
        /// The error reason.
        reason: String,
    },
}

impl fmt::Display for BuildWorkerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BuildWorkerError::Queue(msg) => write!(f, "Build worker queue error: {msg}"),
            BuildWorkerError::Storage(msg) => write!(f, "Build worker storage error: {msg}"),
            BuildWorkerError::BuildService(msg) => write!(f, "Build service error: {msg}"),
            BuildWorkerError::ArtifactService(msg) => write!(f, "Artifact service error: {msg}"),
            BuildWorkerError::InvalidJobVariant(msg) => {
                write!(f, "Invalid job variant for build worker: {msg}")
            }
            BuildWorkerError::StageFailed { stage, reason } => {
                write!(f, "Build stage '{stage}' failed: {reason}")
            }
        }
    }
}

impl std::error::Error for BuildWorkerError {}

impl From<QueueError> for BuildWorkerError {
    fn from(err: QueueError) -> Self {
        BuildWorkerError::Queue(err.to_string())
    }
}

impl From<StorageError> for BuildWorkerError {
    fn from(err: StorageError) -> Self {
        BuildWorkerError::Storage(err.to_string())
    }
}

/// Output summary returned by a successful build job execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BuildWorkerResult {
    /// Public UUID of the completed build.
    pub build_id: String,
    /// Number of stages successfully completed.
    pub stages_completed: usize,
    /// Storage key of the uploaded build log.
    pub log_storage_key: String,
    /// Storage keys of the produced artifacts.
    pub artifact_storage_keys: Vec<String>,
}

/// Executes a single claimed build job with total ack/fail semantics.
///
/// Drives the build lifecycle through domain service layers:
/// 1. Verifies the claimed job payload is `Job::Build`.
/// 2. Iterates over all 9 build stages (`checkout` .. `upload`), reporting `running` then `completed`
///    via [`build_services::update_stage`].
/// 3. Heartbeats the queue claim during long-running work to prevent visibility timeouts.
/// 4. Generates simulated build log and uploads it using [`build_log_storage_key`].
/// 5. Uploads and registers simulated platform artifacts via [`artifact_services::register_artifact`].
/// 6. Marks the build complete via [`build_services::complete_build`].
/// 7. Acknowledges the job from the queue on success; marks `fail` with failure diagnostics on error.
pub async fn run_build_job(
    db: &Database,
    queue: &JobQueue,
    storage: &dyn ObjectStorage,
    consumer_name: &str,
    bucket_name: &str,
    queued_job: QueuedJob,
) -> Result<BuildWorkerResult, BuildWorkerError> {
    let stream_id = queued_job.stream_id.clone();

    let (
        build_id,
        organization_id,
        project_id,
        app_id,
        environment_id,
        git_commit,
        platform,
        build_profile,
    ) = match queued_job.job {
        Job::Build {
            build_id,
            organization_id,
            project_id,
            app_id,
            environment_id,
            git_commit,
            platform,
            build_profile,
        } => (
            build_id,
            organization_id,
            project_id,
            app_id,
            environment_id,
            git_commit,
            platform,
            build_profile,
        ),
        other => {
            let reason = format!("Expected Job::Build, got {}", other.job_type());
            let _ = queue.fail(&stream_id, &reason).await;
            return Err(BuildWorkerError::InvalidJobVariant(reason));
        }
    };

    let ctx = BuildJobContext {
        build_id,
        organization_id,
        project_id,
        app_id,
        environment_id,
        git_commit,
        platform,
        build_profile,
    };
    let build_id = ctx.build_id.clone();

    // Execute internal build pipeline
    match execute_build_pipeline(
        db,
        queue,
        storage,
        consumer_name,
        bucket_name,
        &stream_id,
        &ctx,
    )
    .await
    {
        Ok(result) => {
            // Success: acknowledge the job in Redis Streams
            queue
                .ack(&stream_id)
                .await
                .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;
            Ok(result)
        }
        Err(err) => {
            let error_message = err.to_string();
            eprintln!("Build {build_id} execution failed: {error_message}");

            // Update domain build status to failed
            let req = CompleteBuildRequest {
                status: "failed".to_string(),
                metadata: None,
                logs_url: None,
                reason: Some(error_message.clone()),
            };

            let _ = build_services::complete_build(db, &build_id, req).await;

            // Total failure contract: fail job in queue with reason
            let _ = queue.fail(&stream_id, &error_message).await;

            Err(err)
        }
    }
}

/// The identifiers and build parameters carried by one claimed `Job::Build`.
///
/// Grouped into a struct rather than passed positionally: every field is a `String`, so a
/// positional parameter list silently tolerates a swapped pair (e.g. project_id and app_id),
/// which would write artifacts under the wrong storage prefix.
#[derive(Debug, Clone)]
pub struct BuildJobContext {
    /// Public UUID of the build.
    pub build_id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Public UUID of the parent project.
    pub project_id: String,
    /// Public UUID of the parent app.
    pub app_id: String,
    /// Public UUID of the target environment.
    pub environment_id: String,
    /// Git commit SHA being built.
    pub git_commit: String,
    /// Target platform.
    pub platform: String,
    /// Build profile.
    pub build_profile: String,
}

/// Internal pipeline executing the 9 build stages, artifact upload, and completion.
async fn execute_build_pipeline(
    db: &Database,
    queue: &JobQueue,
    storage: &dyn ObjectStorage,
    consumer_name: &str,
    bucket_name: &str,
    stream_id: &str,
    ctx: &BuildJobContext,
) -> Result<BuildWorkerResult, BuildWorkerError> {
    let BuildJobContext {
        build_id,
        organization_id,
        project_id,
        app_id,
        platform,
        ..
    } = ctx;
    let mut stages_completed = 0;

    // 1. Execute all 9 build stages sequentially
    for stage_name in BUILD_STAGES {
        // Stage started: report running
        let start_req = StageUpdateRequest {
            stage: (*stage_name).to_string(),
            status: "running".to_string(),
            log_snippet: Some(format!("Starting stage {stage_name} on {consumer_name}...")),
            worker_id: Some(consumer_name.to_string()),
        };

        build_services::update_stage(db, build_id, start_req)
            .await
            .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        // Periodic claim heartbeat during stage execution
        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        if *stage_name == "build" {
            // TODO(spec): invoke the Flutter toolchain here; PHASES.md defers execution.
        }

        // Stage completed: report completed
        let complete_req = StageUpdateRequest {
            stage: (*stage_name).to_string(),
            status: "completed".to_string(),
            log_snippet: Some(format!("Stage {stage_name} finished successfully.")),
            worker_id: Some(consumer_name.to_string()),
        };

        build_services::update_stage(db, build_id, complete_req)
            .await
            .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // 2. Upload build logs to canonical storage key
    let log_key = build_log_storage_key(organization_id, project_id, app_id, build_id);
    let log_content = format!(
        "=== Bloom Cloud Build Log ===\nBuild ID: {}\nPlatform: {}\nWorker: {}\nStages: {} completed.\n",
        build_id, platform, consumer_name, stages_completed
    );

    storage
        .put(&log_key, Bytes::from(log_content), "text/plain")
        .await
        .map_err(|e| BuildWorkerError::Storage(e.to_string()))?;

    // 3. Generate and upload canonical build artifact(s)
    let (filename, kind) = match platform.as_str() {
        "android" => ("app-release.aab", "aab"),
        "ios" => ("Runner.ipa", "ipa"),
        "web" => ("web-bundle.tar.gz", "web_bundle"),
        _ => ("artifact.bin", "apk"),
    };

    // Artifact public ID placeholder for registration
    let artifact_temp_id = format!("art-{}", build_id);
    let art_storage_key = artifact_storage_key(
        organization_id,
        project_id,
        app_id,
        build_id,
        &artifact_temp_id,
        filename,
    );

    let dummy_artifact_bytes = Bytes::from(format!("Bloom build output bundle for {build_id}"));
    let dummy_size = dummy_artifact_bytes.len() as i64;
    let dummy_checksum =
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".to_string();

    // Store artifact bytes in storage backend first
    storage
        .put(
            &art_storage_key,
            dummy_artifact_bytes,
            "application/octet-stream",
        )
        .await
        .map_err(|e| BuildWorkerError::Storage(e.to_string()))?;

    // Register artifact metadata in database
    let art_reg_req = ArtifactRegisterRequest {
        build_id: build_id.to_string(),
        organization_id: organization_id.to_string(),
        platform: platform.to_string(),
        kind: kind.to_string(),
        file_name: filename.to_string(),
        file_size: dummy_size,
        checksum: dummy_checksum,
        version: "1.0.0".to_string(),
        build_number: 1,
        metadata: serde_json::json!({
            "worker": consumer_name,
            "platform": platform,
        }),
        storage_bucket: bucket_name.to_string(),
    };

    let saved_artifact = artifact_services::register_artifact(db, storage, art_reg_req)
        .await
        .map_err(|e| BuildWorkerError::ArtifactService(e.to_string()))?;

    // 4. Mark build as completed
    let comp_req = CompleteBuildRequest {
        status: "success".to_string(),
        metadata: Some(serde_json::json!({ "worker": consumer_name }).to_string()),
        logs_url: Some(log_key.clone()),
        reason: None,
    };

    build_services::complete_build(db, build_id, comp_req)
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

    Ok(BuildWorkerResult {
        build_id: build_id.to_string(),
        stages_completed,
        log_storage_key: log_key,
        artifact_storage_keys: vec![saved_artifact.storage_key],
    })
}
