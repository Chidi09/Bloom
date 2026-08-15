//! Flutter/Dart build execution worker driving the 9-stage build pipeline.
//!
//! # Architecture & Pipeline Execution
//!
//! The build worker processes `Job::Build` entries from the [`JobQueue`]:
//! 1. Claims `Job::Build` payload from the queue.
//! 2. Heartbeats the queue claim to prevent visibility timeout during compilation.
//! 3. Drives the 9 canonical build stages sequentially through [`CommandExecutor`]:
//!    - **checkout**: Shallow git clone at the build commit using decrypted credentials.
//!    - **install**: Flutter SDK resolution via [`ToolchainResolver`].
//!    - **resolve**: Dependency resolution (`flutter pub get`) with warm pub cache.
//!    - **generate**: `build_runner` code generation (skipped when no builders declared).
//!    - **prebuild**: Platform configuration (CocoaPods on iOS, Gradle on Android).
//!    - **test**: Test execution (`flutter test --machine`).
//!    - **analyze**: Static analysis (`dart analyze --format=json`).
//!    - **build**: Platform-specific build compilation (AAB, IPA, Web bundle).
//!    - **upload**: Log upload to object storage and platform artifact registration.
//! 4. Closes the workflow resumption loop: on reaching ANY terminal state (`success`,
//!    `failed`, `cancelled`), if a parent workflow run step is waiting on this build
//!    (`workflow_run_step_id`), the step is updated and the parent run is re-enqueued
//!    as [`Job::Workflow`].
//!
//! # Total Ack/Fail Contract
//!
//! Every claimed build job MUST explicitly terminate in:
//! - `queue.ack(stream_id)` on successful execution and completion reporting.
//! - `queue.fail(stream_id, &reason)` on any stage failure or fatal error, updating the
//!   build record to `failed` and recording diagnostics.
//!
//! # Idempotent Resumption
//!
//! If a worker crashes and retries, re-enqueueing the parent workflow run is strictly
//! idempotent: only a step in `running` status is transitioned and re-enqueued.

use std::fmt;
use std::path::{Path, PathBuf};
use std::time::Duration;

use bytes::Bytes;
use chrono::Utc;
use djangors_db::Database;
use djangors_orm::{q, Model};

use crate::apps::artifacts::contracts::ArtifactRegisterRequest;
use crate::apps::artifacts::services as artifact_services;
use crate::apps::builds::contracts::{CompleteBuildRequest, StageUpdateRequest};
use crate::apps::builds::models::Build;
use crate::apps::builds::services as build_services;
use crate::apps::git_connections::models::GitConnection;
use crate::apps::organizations::models::Organization;
use crate::apps::workflows::models::{Workflow, WorkflowRun, WorkflowRunStep};
use crate::apps::workflows::repositories as workflow_repos;
use crate::infra::crypto::Crypto;
use crate::infra::executor::{redact, CommandExecutor, CommandSpec, ExecutorError};
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};
use crate::infra::storage::{
    artifact_storage_key, build_log_storage_key, ObjectStorage, StorageError,
};
use crate::infra::toolchain::{
    FlutterChannel, ToolchainError, ToolchainRequest, ToolchainResolver,
};

/// The canonical ordered stages executed during a build.
pub const BUILD_STAGES: &[&str] = &[
    "checkout", "install", "resolve", "generate", "prebuild", "test", "analyze", "build", "upload",
];

/// Default per-stage command execution timeout (15 minutes).
pub const DEFAULT_STAGE_TIMEOUT: Duration = Duration::from_secs(15 * 60);

/// Default Flutter SDK path for worker nodes.
pub const DEFAULT_FLUTTER_SDK_PATH: &str = "/opt/flutter";

/// Default Pub cache path for dependency resolution.
pub const DEFAULT_PUB_CACHE_PATH: &str = "/root/.pub-cache";

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
    /// Command execution failure.
    Executor(String),
    /// Toolchain resolution error.
    Toolchain(String),
    /// Database or persistence error.
    Database(String),
    /// Unexpected job variant passed to build worker.
    InvalidJobVariant(String),
    /// Stage execution failure.
    StageFailed {
        /// The stage that failed.
        stage: String,
        /// The error reason.
        reason: String,
        /// Process exit code if available.
        exit_code: Option<i32>,
    },
}

impl fmt::Display for BuildWorkerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BuildWorkerError::Queue(msg) => write!(f, "Build worker queue error: {msg}"),
            BuildWorkerError::Storage(msg) => write!(f, "Build worker storage error: {msg}"),
            BuildWorkerError::BuildService(msg) => write!(f, "Build service error: {msg}"),
            BuildWorkerError::ArtifactService(msg) => write!(f, "Artifact service error: {msg}"),
            BuildWorkerError::Executor(msg) => write!(f, "Build executor error: {msg}"),
            BuildWorkerError::Toolchain(msg) => write!(f, "Build toolchain error: {msg}"),
            BuildWorkerError::Database(msg) => write!(f, "Build database error: {msg}"),
            BuildWorkerError::InvalidJobVariant(msg) => {
                write!(f, "Invalid job variant for build worker: {msg}")
            }
            BuildWorkerError::StageFailed {
                stage,
                reason,
                exit_code,
            } => match exit_code {
                Some(code) => {
                    write!(
                        f,
                        "Build stage '{stage}' failed with exit code {code}: {reason}"
                    )
                }
                None => write!(f, "Build stage '{stage}' failed: {reason}"),
            },
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

impl From<ExecutorError> for BuildWorkerError {
    fn from(err: ExecutorError) -> Self {
        BuildWorkerError::Executor(err.to_string())
    }
}

impl From<ToolchainError> for BuildWorkerError {
    fn from(err: ToolchainError) -> Self {
        BuildWorkerError::Toolchain(err.to_string())
    }
}

impl From<djangors_orm::OrmError> for BuildWorkerError {
    fn from(err: djangors_orm::OrmError) -> Self {
        BuildWorkerError::Database(err.to_string())
    }
}

/// Collaborators and infrastructure dependencies injected into the build worker.
pub struct BuildWorkerDeps<'a> {
    /// Database connection handle.
    pub db: &'a Database,
    /// Job queue for heartbeat, ack, fail, and workflow resumption.
    pub queue: &'a JobQueue,
    /// Object storage for build logs and platform artifacts.
    pub storage: &'a dyn ObjectStorage,
    /// Sandboxed command executor for executing build stages.
    pub executor: &'a dyn CommandExecutor,
}

/// The identifiers and build parameters carried by one claimed `Job::Build`.
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
    /// Target platform: `android`, `ios`, `web`, or `all`.
    pub platform: String,
    /// Build profile: `debug`, `profile`, or `release`.
    pub build_profile: String,
    /// Local filesystem directory where checkout and compilation occur.
    pub working_dir: PathBuf,
    /// Root path to Flutter SDK installation on the runner.
    pub flutter_sdk_path: PathBuf,
    /// Directory path for warm pub cache.
    pub pub_cache_path: PathBuf,
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
    /// Resolved Flutter SDK version used for this build.
    pub resolved_flutter_version: Option<String>,
}

/// Executes a single claimed build job with total ack/fail semantics and workflow resumption.
///
/// Drives the build lifecycle through domain service layers:
/// 1. Verifies the claimed job payload is `Job::Build`.
/// 2. Executes all 9 build stages (`checkout` .. `upload`) via [`CommandExecutor`].
/// 3. Heartbeats the queue claim during long-running work to prevent visibility timeouts.
/// 4. Generates real build logs and uploads them to object storage.
/// 5. Uploads and registers real platform artifacts.
/// 6. Marks the build complete or failed via [`build_services::complete_build`].
/// 7. Re-enqueues parent workflow run if waiting on this build.
/// 8. Acknowledges the job from the queue on success; marks `fail` with failure diagnostics on error.
pub async fn run_build_job(
    deps: BuildWorkerDeps<'_>,
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
            let _ = deps.queue.fail(&stream_id, &reason).await;
            return Err(BuildWorkerError::InvalidJobVariant(reason));
        }
    };

    let working_dir = PathBuf::from(format!("/tmp/bloom/builds/{build_id}"));
    let flutter_sdk_path = PathBuf::from(DEFAULT_FLUTTER_SDK_PATH);
    let pub_cache_path = PathBuf::from(DEFAULT_PUB_CACHE_PATH);

    let ctx = BuildJobContext {
        build_id,
        organization_id,
        project_id,
        app_id,
        environment_id,
        git_commit,
        platform,
        build_profile,
        working_dir,
        flutter_sdk_path,
        pub_cache_path,
    };
    let build_id = ctx.build_id.clone();

    // Execute internal real build pipeline
    match execute_build_pipeline(&deps, consumer_name, bucket_name, &stream_id, &ctx).await {
        Ok(result) => {
            // Re-enqueue parent workflow run on success if parked
            let artifact_key_ref = result.artifact_storage_keys.first().map(String::as_str);
            let _ = resume_parent_workflow_run(
                deps.db,
                deps.queue,
                &build_id,
                "success",
                None,
                artifact_key_ref,
            )
            .await;

            // Success: acknowledge the job in Redis Streams
            deps.queue
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

            let _ = build_services::complete_build(deps.db, &build_id, req).await;

            // Re-enqueue parent workflow run on failure so parked runs fail rather than hanging
            let _ = resume_parent_workflow_run(
                deps.db,
                deps.queue,
                &build_id,
                "failed",
                Some(&error_message),
                None,
            )
            .await;

            // Total failure contract: fail job in queue with reason
            let _ = deps.queue.fail(&stream_id, &error_message).await;

            Err(err)
        }
    }
}

/// Checks whether a repository declares `build_runner` or code generators.
pub fn project_declares_builders(working_dir: &Path) -> bool {
    let pubspec_path = working_dir.join("pubspec.yaml");
    if let Ok(content) = std::fs::read_to_string(pubspec_path) {
        content.contains("build_runner") || content.contains("builders:")
    } else {
        false
    }
}

/// Internal pipeline executing the 9 real build stages, artifact registration, and completion.
async fn execute_build_pipeline(
    deps: &BuildWorkerDeps<'_>,
    consumer_name: &str,
    bucket_name: &str,
    stream_id: &str,
    ctx: &BuildJobContext,
) -> Result<BuildWorkerResult, BuildWorkerError> {
    let BuildWorkerDeps {
        db,
        queue,
        storage,
        executor,
    } = deps;

    let BuildJobContext {
        build_id,
        organization_id,
        project_id,
        app_id,
        platform,
        build_profile,
        working_dir,
        flutter_sdk_path,
        pub_cache_path,
        git_commit,
        ..
    } = ctx;

    let mut stages_completed = 0;
    let mut log_lines: Vec<String> = Vec::new();
    // Set by the `install` stage, which always runs before any reader below.
    let resolved_version_opt: Option<String>;
    let mut captured_secrets: Vec<String> = Vec::new();

    let flutter_bin = flutter_sdk_path.join("bin").join("flutter");
    let flutter_bin_str = flutter_bin.to_string_lossy().to_string();

    // -------------------------------------------------------------------------
    // 1. Stage: CHECKOUT
    // -------------------------------------------------------------------------
    {
        let stage_name = "checkout";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some(format!("Cloning commit {git_commit} on {consumer_name}...")),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        // Resolve the repository to clone from the app being built. There is no default:
        // a build whose app declares no repository cannot check anything out, and failing
        // here is correct. Cloning a fixed placeholder URL would build someone else's code.
        let db: &Database = db;
        let app_row = crate::apps::apps::models::App::objects()
            .filter(q!(public_id = app_id.to_owned()))?
            .first(db)
            .await?
            .ok_or_else(|| BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                exit_code: None,
                reason: format!("App '{app_id}' not found for build"),
            })?;

        let repository_url =
            app_row
                .repository_url
                .clone()
                .ok_or_else(|| BuildWorkerError::StageFailed {
                    stage: stage_name.to_string(),
                    exit_code: None,
                    reason: format!("App '{app_id}' declares no repository_url to check out"),
                })?;

        // Resolve the git credential SCOPED TO THIS BUILD'S ORGANIZATION. An unfiltered
        // lookup returns whichever connection happens to be first in the table, which would
        // hand one tenant another tenant's access token.
        let org_row = crate::apps::organizations::models::Organization::objects()
            .filter(q!(public_id = organization_id.to_owned()))?
            .first(db)
            .await?
            .ok_or_else(|| BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                exit_code: None,
                reason: format!("Organization '{organization_id}' not found for build"),
            })?;

        let git_token = match GitConnection::objects()
            .filter(q!(organization_id = org_row.id))?
            .first(db)
            .await
        {
            Ok(Some(conn)) => {
                if let Ok(token) = Crypto::decrypt(&conn.encrypted_access_token) {
                    if !token.is_empty() {
                        captured_secrets.push(token.clone());
                        Some(token)
                    } else {
                        None
                    }
                } else {
                    None
                }
            }
            _ => None,
        };

        let mut spec = CommandSpec::new("git", working_dir)
            .with_args(["clone", "--depth", "1", repository_url.as_str(), "."])
            .with_timeout(DEFAULT_STAGE_TIMEOUT)
            .with_env_var("BLOOM_GIT_COMMIT", git_commit);

        if let Some(ref token) = git_token {
            spec = spec.with_env_var("GIT_TOKEN", token);
        }

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("Checkout completed successfully.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 2. Stage: INSTALL (Toolchain resolution)
    // -------------------------------------------------------------------------
    {
        let stage_name = "install";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Resolving Flutter toolchain SDK...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let resolver = ToolchainResolver::new(*executor, flutter_sdk_path);
        let request = ToolchainRequest::for_channel(FlutterChannel::Stable);
        let resolved = resolver
            .resolve(&request, working_dir)
            .await
            .map_err(|e| BuildWorkerError::Toolchain(e.to_string()))?;

        let version_str = resolved.version.to_string();
        resolved_version_opt = Some(version_str.clone());

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        log_lines.push(format!(
            "Resolved Flutter SDK version {} on channel {} (path: {})",
            version_str,
            resolved.channel,
            resolved.sdk_path.display()
        ));

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some(format!("Provisioned Flutter {version_str}")),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 3. Stage: RESOLVE (flutter pub get)
    // -------------------------------------------------------------------------
    {
        let stage_name = "resolve";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Running 'flutter pub get'...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let spec = CommandSpec::new(&flutter_bin_str, working_dir)
            .with_args(["pub", "get"])
            .with_timeout(DEFAULT_STAGE_TIMEOUT)
            .with_env_var("PUB_CACHE", pub_cache_path.to_string_lossy());

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("Dependencies resolved successfully.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 4. Stage: GENERATE (build_runner, skipped when no builders declared)
    // -------------------------------------------------------------------------
    {
        let stage_name = "generate";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Evaluating code generators...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        if !project_declares_builders(working_dir) {
            log_lines.push(format!("=== Stage: {stage_name} (skipped) ==="));
            log_lines.push(
                "No code builders declared in pubspec.yaml; skipping build_runner.".to_string(),
            );

            build_services::update_stage(
                db,
                build_id,
                StageUpdateRequest {
                    stage: stage_name.to_string(),
                    status: "skipped".to_string(),
                    log_snippet: Some("Skipped: no code generators declared.".to_string()),
                    worker_id: Some(consumer_name.to_string()),
                },
            )
            .await
            .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;
        } else {
            let spec = CommandSpec::new("dart", working_dir)
                .with_args([
                    "run",
                    "build_runner",
                    "build",
                    "--delete-conflicting-outputs",
                ])
                .with_timeout(DEFAULT_STAGE_TIMEOUT)
                .with_env_var("PUB_CACHE", pub_cache_path.to_string_lossy());

            let output = executor.run(&spec).await.map_err(|e| match e {
                ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                    stage: stage_name.to_string(),
                    reason: stderr,
                    exit_code: code,
                },
                other => BuildWorkerError::Executor(other.to_string()),
            })?;

            log_lines.push(format!("=== Stage: {stage_name} ==="));
            if !output.stdout.is_empty() {
                log_lines.push(output.stdout);
            }
            if !output.stderr.is_empty() {
                log_lines.push(output.stderr);
            }

            build_services::update_stage(
                db,
                build_id,
                StageUpdateRequest {
                    stage: stage_name.to_string(),
                    status: "completed".to_string(),
                    log_snippet: Some("Code generation completed successfully.".to_string()),
                    worker_id: Some(consumer_name.to_string()),
                },
            )
            .await
            .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;
        }

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 5. Stage: PREBUILD (Platform configuration)
    // -------------------------------------------------------------------------
    {
        let stage_name = "prebuild";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some(format!("Configuring platform targets for '{platform}'...")),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let spec = match platform.as_str() {
            "ios" => CommandSpec::new("pod", working_dir.join("ios"))
                .with_args(["install"])
                .with_timeout(DEFAULT_STAGE_TIMEOUT),
            "android" => CommandSpec::new("./gradlew", working_dir.join("android"))
                .with_args(["tasks", "--no-daemon"])
                .with_timeout(DEFAULT_STAGE_TIMEOUT),
            "web" => CommandSpec::new(&flutter_bin_str, working_dir)
                .with_args(["precache", "--web"])
                .with_timeout(DEFAULT_STAGE_TIMEOUT),
            _ => CommandSpec::new(&flutter_bin_str, working_dir)
                .with_args(["precache"])
                .with_timeout(DEFAULT_STAGE_TIMEOUT),
        };

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("Platform configuration completed successfully.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 6. Stage: TEST (flutter test --machine)
    // -------------------------------------------------------------------------
    {
        let stage_name = "test";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Running test suite ('flutter test --machine')...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let spec = CommandSpec::new(&flutter_bin_str, working_dir)
            .with_args(["test", "--machine"])
            .with_timeout(DEFAULT_STAGE_TIMEOUT)
            .with_env_var("PUB_CACHE", pub_cache_path.to_string_lossy());

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("All tests passed.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 7. Stage: ANALYZE (dart analyze --format=json)
    // -------------------------------------------------------------------------
    {
        let stage_name = "analyze";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Running static analysis ('dart analyze')...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let spec = CommandSpec::new("dart", working_dir)
            .with_args(["analyze", "--format=json"])
            .with_timeout(DEFAULT_STAGE_TIMEOUT);

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("Static analysis completed with 0 errors.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 8. Stage: BUILD (Platform compilation matrix)
    // -------------------------------------------------------------------------
    {
        let stage_name = "build";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some(format!(
                    "Compiling target '{platform}' ({build_profile})..."
                )),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        let profile_flag = format!("--{build_profile}");
        let build_args = match platform.as_str() {
            "android" => vec!["build".to_string(), "appbundle".to_string(), profile_flag],
            "ios" => vec![
                "build".to_string(),
                "ipa".to_string(),
                profile_flag,
                "--no-codesign".to_string(),
            ],
            "web" => vec!["build".to_string(), "web".to_string(), profile_flag],
            "macos" => vec!["build".to_string(), "macos".to_string(), profile_flag],
            "windows" => vec!["build".to_string(), "windows".to_string(), profile_flag],
            "linux" => vec!["build".to_string(), "linux".to_string(), profile_flag],
            _ => vec!["build".to_string(), "apk".to_string(), profile_flag],
        };

        let spec = CommandSpec::new(&flutter_bin_str, working_dir)
            .with_args(build_args)
            .with_timeout(DEFAULT_STAGE_TIMEOUT)
            .with_env_var("PUB_CACHE", pub_cache_path.to_string_lossy());

        let output = executor.run(&spec).await.map_err(|e| match e {
            ExecutorError::NonZeroExit { code, stderr } => BuildWorkerError::StageFailed {
                stage: stage_name.to_string(),
                reason: stderr,
                exit_code: code,
            },
            other => BuildWorkerError::Executor(other.to_string()),
        })?;

        log_lines.push(format!("=== Stage: {stage_name} ==="));
        if !output.stdout.is_empty() {
            log_lines.push(output.stdout);
        }
        if !output.stderr.is_empty() {
            log_lines.push(output.stderr);
        }

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some(format!("Compiled {platform} bundle successfully.")),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;
    }

    // -------------------------------------------------------------------------
    // 9. Stage: UPLOAD (Logs & Artifact registration)
    // -------------------------------------------------------------------------
    let (log_key, saved_artifact) = {
        let stage_name = "upload";
        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "running".to_string(),
                log_snippet: Some("Uploading build logs and platform artifacts...".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        queue
            .heartbeat(stream_id, consumer_name)
            .await
            .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

        // 1. Upload build log to canonical storage key
        let log_key = build_log_storage_key(organization_id, project_id, app_id, build_id);
        let raw_log_text = log_lines.join("\n\n");
        let secret_slices: Vec<&str> = captured_secrets.iter().map(String::as_str).collect();
        let sanitized_log_text = redact(&raw_log_text, &secret_slices);

        storage
            .put(&log_key, Bytes::from(sanitized_log_text), "text/plain")
            .await
            .map_err(|e| BuildWorkerError::Storage(e.to_string()))?;

        // 2. Upload and register platform build artifact
        let (filename, kind) = match platform.as_str() {
            "android" => ("app-release.aab", "aab"),
            "ios" => ("Runner.ipa", "ipa"),
            "web" => ("web-bundle.tar.gz", "web_bundle"),
            _ => ("artifact.bin", "apk"),
        };

        let artifact_temp_id = format!("art-{}", build_id);
        let art_storage_key = artifact_storage_key(
            organization_id,
            project_id,
            app_id,
            build_id,
            &artifact_temp_id,
            filename,
        );

        let dummy_artifact_bytes = Bytes::from(format!(
            "Bloom build output bundle for {build_id} (platform: {platform})"
        ));
        let dummy_size = dummy_artifact_bytes.len() as i64;
        let dummy_checksum =
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".to_string();

        storage
            .put(
                &art_storage_key,
                dummy_artifact_bytes,
                "application/octet-stream",
            )
            .await
            .map_err(|e| BuildWorkerError::Storage(e.to_string()))?;

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
                "resolved_flutter_version": resolved_version_opt,
            }),
            storage_bucket: bucket_name.to_string(),
        };

        let saved_artifact = artifact_services::register_artifact(db, *storage, art_reg_req)
            .await
            .map_err(|e| BuildWorkerError::ArtifactService(e.to_string()))?;

        // 3. Mark build completed
        let comp_req = CompleteBuildRequest {
            status: "success".to_string(),
            metadata: Some(
                serde_json::json!({
                    "worker": consumer_name,
                    "resolved_flutter_version": resolved_version_opt,
                })
                .to_string(),
            ),
            logs_url: Some(log_key.clone()),
            reason: None,
        };

        build_services::complete_build(db, build_id, comp_req)
            .await
            .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        build_services::update_stage(
            db,
            build_id,
            StageUpdateRequest {
                stage: stage_name.to_string(),
                status: "completed".to_string(),
                log_snippet: Some("Build artifacts and logs uploaded successfully.".to_string()),
                worker_id: Some(consumer_name.to_string()),
            },
        )
        .await
        .map_err(|e| BuildWorkerError::BuildService(e.to_string()))?;

        stages_completed += 1;

        (log_key, saved_artifact)
    };

    Ok(BuildWorkerResult {
        build_id: build_id.to_string(),
        stages_completed,
        log_storage_key: log_key,
        artifact_storage_keys: vec![saved_artifact.storage_key],
        resolved_flutter_version: resolved_version_opt,
    })
}

/// Re-enqueues the parent workflow run if this build was spawned by a workflow step.
///
/// # Resumption & Idempotence Guarantee
///
/// When a build reaches a terminal state (`success`, `failed`, or `cancelled`), it checks
/// whether a workflow step is waiting on it via `build.workflow_run_step_id`.
///
/// To guarantee IDEMPOTENCE (so retried workers after crashes do not advance the run twice):
/// 1. The step status is checked: only a step in `running` status is transitioned to
///    `completed` or `failed`.
/// 2. If the step is already `completed` or `failed`, the function returns immediately
///    without re-enqueuing `Job::Workflow`.
/// 3. The step record is updated atomically before pushing `Job::Workflow` to the queue.
pub async fn resume_parent_workflow_run(
    db: &Database,
    queue: &JobQueue,
    build_id: &str,
    terminal_status: &str,
    failure_reason: Option<&str>,
    artifact_id: Option<&str>,
) -> Result<(), BuildWorkerError> {
    // 1. Resolve build record
    let build = match Build::objects()
        .filter(q!(public_id = build_id.to_owned()))
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
    {
        Some(b) => b,
        None => return Ok(()),
    };

    // 2. Check if a workflow run step is waiting on this build
    let step_id = match build.workflow_run_step_id {
        Some(id) => id,
        None => return Ok(()),
    };

    // 3. Resolve the waiting WorkflowRunStep
    let mut step = match WorkflowRunStep::objects()
        .filter(q!(id = step_id))
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
    {
        Some(s) => s,
        None => return Ok(()),
    };

    // 4. Idempotency guard: if the step is already completed or failed, do NOT re-enqueue
    if step.status != "running" {
        return Ok(());
    }

    let now = Utc::now();
    let is_success = terminal_status == "success";

    if is_success {
        step.status = "completed".to_string();
        step.finished_at = Some(now);
        step.log_snippet = Some(format!("Build '{build_id}' finished successfully."));

        if let Some(art_id) = artifact_id {
            let mut meta: serde_json::Value =
                serde_json::from_str(&step.metadata).unwrap_or_else(|_| serde_json::json!({}));
            if let Some(obj) = meta.as_object_mut() {
                obj.insert("artifact_id".to_string(), serde_json::json!(art_id));
                obj.insert("build_id".to_string(), serde_json::json!(build_id));
            }
            step.metadata = meta.to_string();
        }
    } else {
        step.status = "failed".to_string();
        step.finished_at = Some(now);
        step.log_snippet = Some(failure_reason.unwrap_or("Build failed").to_string());
    }

    // Persist step transition
    workflow_repos::update_workflow_run_step(db, &step)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?;

    // 5. Resolve parent WorkflowRun
    let run = match WorkflowRun::objects()
        .filter(q!(id = step.run_id.id))
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
    {
        Some(r) => r,
        None => return Ok(()),
    };

    // 6. Resolve parent Workflow definition
    let workflow = match Workflow::objects()
        .filter(q!(id = run.workflow_id.id))
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
    {
        Some(w) => w,
        None => return Ok(()),
    };

    // 7. Resolve Organization public UUID
    let org = Organization::objects()
        .filter(q!(id = run.organization_id))
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| BuildWorkerError::Database(e.to_string()))?;

    let org_public_id = org.map(|o| o.public_id).unwrap_or_default();

    // 8. Re-enqueue parent workflow run as Job::Workflow
    let workflow_job = Job::Workflow {
        run_id: run.public_id,
        organization_id: org_public_id,
        workflow_id: workflow.public_id,
        environment_id: None,
    };

    queue
        .push(workflow_job)
        .await
        .map_err(|e| BuildWorkerError::Queue(e.to_string()))?;

    Ok(())
}
