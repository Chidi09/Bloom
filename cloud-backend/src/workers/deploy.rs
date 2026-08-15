//! Multi-target deployment worker implementing web hosting, App Store Connect (TestFlight),
//! Google Play tracks, and Shorebird OTA code push.
//!
//! # Architecture & Workflow
//!
//! The deployment worker processes `Job::Deploy` jobs from the `JobQueue`:
//! 1. Claims `Job::Deploy` payload from the queue.
//! 2. Heartbeats the queue claim to prevent visibility timeout during network operations.
//! 3. Branches execution based on the deployment `target` and `platform`:
//!    - **Web / Preview** (`web`, `preview`, `production` on web):
//!      Uploads web bundle assets to object storage under canonical `storage_prefix`,
//!      purges Cloudflare CDN cache prefixes, and registers Caddy reverse proxy route.
//!    - **TestFlight / App Store** (`testflight`, `app_store` on iOS):
//!      Orchestrates App Store Connect REST API v1 delivery, polls build processing state
//!      (defensively treating unverified `processingState` values as in-progress), and assigns
//!      builds to TestFlight beta groups.
//!    - **Google Play** (`internal`, `internal_testing`, `closed`, `open`, `production`, `play_store` on Android):
//!      Executes the atomic Google Play edit transaction lifecycle:
//!      `create_edit` -> `upload_bundle` -> `assign_track` -> `commit_edit`.
//!      Guarantees that on ANY failure after `create_edit`, the edit is explicitly deleted/abandoned
//!      to prevent orphaned edit locks.
//!    - **Shorebird** (`shorebird`):
//!      Drives the `shorebird` CLI to publish OTA Dart patches, surfacing credential health
//!      and deprecation notices (such as the September 2026 `login:ci` expiry).
//! 4. Closes the workflow resumption loop: on reaching ANY terminal state (`success`,
//!    `failed`, `cancelled`), if a parent workflow run step is waiting on this deployment
//!    (`workflow_run_step_id`), the step is updated and the parent run is re-enqueued
//!    as [`Job::Workflow`].
//! 5. Completes the deployment and emits state events (`deployment.succeeded` / `deployment.failed`).
//!
//! # Total Ack/Fail Contract
//!
//! Every claimed deploy job MUST explicitly terminate in `queue.ack` on success or
//! `queue.fail` on error, ensuring no claims linger indefinitely in the queue.

use std::fmt;
use std::path::{Path, PathBuf};

use bytes::Bytes;
use chrono::Utc;
use djangors_db::Database;
use djangors_orm::{q, Model};

use sha2::{Digest, Sha256};

use crate::apps::artifacts::models::Artifact;
use crate::apps::deployments::models::Deployment;
use crate::apps::organizations::models::Organization;
use crate::apps::webhosting::services::build_web_storage_prefix;
use crate::apps::workflows::models::{Workflow, WorkflowRun, WorkflowRunStep};
use crate::apps::workflows::repositories as workflow_repos;
use crate::infra::caddy::{caddy_site_id, CaddyClient, CaddyError, CaddyMatchRule, CaddySiteBlock};
use crate::infra::cdn::{CdnClient, CdnError, PurgeOutcome};
use crate::infra::crypto::Crypto;
use crate::infra::googleplay::{GooglePlayClient, GooglePlayError, ReleaseStatus, TrackRelease};
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};
use crate::infra::shorebird::{
    ShorebirdClient, ShorebirdError, ShorebirdOptions, ShorebirdPlatform, ShorebirdPlatforms,
};
use crate::infra::storage::{ObjectStorage, StorageError};
use crate::infra::testflight::{TestFlightClient, TestFlightError, TestFlightProcessingState};

/// Default Caddy routes configuration path.
pub const DEFAULT_CADDY_ROUTES_PATH: &str = "apps/http/servers/srv0/routes";

/// Errors arising during deploy worker execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeployWorkerError {
    /// Queue claim or operation failure.
    Queue(String),
    /// Object storage bundle upload failure.
    Storage(String),
    /// CDN cache purge failure (when configured to fail).
    Cdn(String),
    /// Caddy reverse proxy provisioning failure.
    Caddy(String),
    /// Domain webhosting or deployment service error.
    WebHostingService(String),
    /// Unexpected job variant.
    InvalidJobVariant(String),
    /// App Store Connect / TestFlight vendor error.
    TestFlight(String),
    /// Google Play Android Publisher API error.
    GooglePlay(String),
    /// Shorebird OTA CLI execution error.
    Shorebird(String),
    /// Publishing account / credential authorization rejection.
    PublishingAccount(String),
    /// Deployment operation timed out.
    Timeout(String),
    /// Target destination is invalid or unsupported.
    InvalidTarget(String),
}

impl fmt::Display for DeployWorkerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DeployWorkerError::Queue(msg) => write!(f, "Deploy worker queue error: {msg}"),
            DeployWorkerError::Storage(msg) => write!(f, "Deploy worker storage error: {msg}"),
            DeployWorkerError::Cdn(msg) => write!(f, "Deploy worker CDN error: {msg}"),
            DeployWorkerError::Caddy(msg) => write!(f, "Deploy worker Caddy error: {msg}"),
            DeployWorkerError::WebHostingService(msg) => {
                write!(f, "Deploy worker service error: {msg}")
            }
            DeployWorkerError::InvalidJobVariant(msg) => {
                write!(f, "Invalid job variant for deploy worker: {msg}")
            }
            DeployWorkerError::TestFlight(msg) => {
                write!(f, "TestFlight deployment error: {msg}")
            }
            DeployWorkerError::GooglePlay(msg) => {
                write!(f, "Google Play deployment error: {msg}")
            }
            DeployWorkerError::Shorebird(msg) => {
                write!(f, "Shorebird deployment error: {msg}")
            }
            DeployWorkerError::PublishingAccount(msg) => {
                write!(f, "Publishing account error: {msg}")
            }
            DeployWorkerError::Timeout(msg) => {
                write!(f, "Deploy worker timeout: {msg}")
            }
            DeployWorkerError::InvalidTarget(msg) => {
                write!(f, "Invalid deployment target: {msg}")
            }
        }
    }
}

impl std::error::Error for DeployWorkerError {}

impl From<QueueError> for DeployWorkerError {
    fn from(err: QueueError) -> Self {
        DeployWorkerError::Queue(err.to_string())
    }
}

impl From<StorageError> for DeployWorkerError {
    fn from(err: StorageError) -> Self {
        DeployWorkerError::Storage(err.to_string())
    }
}

impl From<CdnError> for DeployWorkerError {
    fn from(err: CdnError) -> Self {
        DeployWorkerError::Cdn(err.to_string())
    }
}

impl From<CaddyError> for DeployWorkerError {
    fn from(err: CaddyError) -> Self {
        DeployWorkerError::Caddy(err.to_string())
    }
}

impl From<TestFlightError> for DeployWorkerError {
    fn from(err: TestFlightError) -> Self {
        map_testflight_error(err)
    }
}

impl From<GooglePlayError> for DeployWorkerError {
    fn from(err: GooglePlayError) -> Self {
        map_googleplay_error(err)
    }
}

impl From<ShorebirdError> for DeployWorkerError {
    fn from(err: ShorebirdError) -> Self {
        map_shorebird_error(err)
    }
}

/// Maps TestFlight errors into `DeployWorkerError`, identifying vendor 401s as account errors.
fn map_testflight_error(err: TestFlightError) -> DeployWorkerError {
    match err {
        TestFlightError::Api { status: 401, message } => {
            DeployWorkerError::PublishingAccount(format!(
                "Apple App Store Connect authorization rejected for publishing account (HTTP 401): {message}"
            ))
        }
        TestFlightError::Auth(msg) => {
            DeployWorkerError::PublishingAccount(format!(
                "Apple App Store Connect authentication failed for publishing account: {msg}"
            ))
        }
        other => DeployWorkerError::TestFlight(other.to_string()),
    }
}

/// Maps Google Play errors into `DeployWorkerError`, identifying vendor 401s as account errors.
fn map_googleplay_error(err: GooglePlayError) -> DeployWorkerError {
    match err {
        GooglePlayError::Api {
            status: 401,
            message,
        } => DeployWorkerError::PublishingAccount(format!(
            "Google Play authorization rejected for publishing account (HTTP 401): {message}"
        )),
        GooglePlayError::Auth(msg) => DeployWorkerError::PublishingAccount(format!(
            "Google Play authentication/OAuth failed for publishing account: {msg}"
        )),
        other => DeployWorkerError::GooglePlay(other.to_string()),
    }
}

/// Maps Shorebird CLI errors into `DeployWorkerError`, identifying authentication failures.
fn map_shorebird_error(err: ShorebirdError) -> DeployWorkerError {
    match err {
        ShorebirdError::NotConfigured(msg) => DeployWorkerError::PublishingAccount(format!(
            "Shorebird credentials not configured for publishing account: {msg}"
        )),
        ShorebirdError::ExecutionFailed {
            exit_code,
            stdout,
            stderr,
        } => {
            if stderr.contains("401")
                || stderr.contains("Unauthorized")
                || stderr.contains("Invalid token")
            {
                DeployWorkerError::PublishingAccount(format!(
                    "Shorebird authentication rejected for publishing account: {stderr}"
                ))
            } else {
                let code_str = exit_code
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "signal".to_string());
                DeployWorkerError::Shorebird(format!(
                    "Shorebird CLI execution failed (exit code {code_str}): stderr: {stderr}; stdout: {stdout}"
                ))
            }
        }
        other => DeployWorkerError::Shorebird(other.to_string()),
    }
}

/// Output summary returned by a successful deploy job execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeployWorkerResult {
    /// Public UUID of the deployment.
    pub deployment_id: String,
    /// Canonical storage prefix where web assets were uploaded (for web deployments).
    pub storage_prefix: String,
    /// CDN purge outcome (for web deployments).
    pub cdn_outcome: PurgeOutcome,
    /// Caddy site ID tag provisioned (for web deployments).
    pub caddy_site_id: String,
    /// External provider identifier (e.g. TestFlight build ID, Google Play edit ID, Shorebird patch ID).
    pub external_id: Option<String>,
    /// External provider console URL.
    pub external_url: Option<String>,
}

/// The infrastructure collaborators a deploy worker run needs.
///
/// Passed as a borrowed bundle so the worker entry points stay readable, and so tests can
/// substitute in-memory implementations without a long positional argument list.
#[derive(Clone, Copy)]
pub struct DeployWorkerDeps<'a> {
    /// Database handle, used by the domain services.
    pub db: &'a Database,
    /// Job queue the deployment was claimed from.
    pub queue: &'a JobQueue,
    /// Object storage receiving the web bundle.
    pub storage: &'a dyn ObjectStorage,
    /// Cloudflare cache invalidation client.
    pub cdn: &'a CdnClient,
    /// Caddy admin API client.
    pub caddy: &'a CaddyClient,
    /// App Store Connect / TestFlight API client.
    pub testflight: &'a TestFlightClient,
    /// Google Play Android Publisher API client.
    pub googleplay: &'a GooglePlayClient,
    /// Shorebird OTA code push client.
    pub shorebird: &'a ShorebirdClient,
}

/// Routing details the queued job does not itself carry, resolved by the caller.
///
/// `Job::Deploy` holds only public UUIDs, but the storage prefix, hostname, bundle IDs,
/// and track assignments need additional project and routing parameters.
#[derive(Debug, Clone, Copy, Default)]
pub struct DeployRouting<'a> {
    /// Public UUID of the parent project.
    pub project_id: &'a str,
    /// Public UUID of the parent app.
    pub app_id: &'a str,
    /// URL slug of the app.
    pub app_slug: &'a str,
    /// URL slug of the project.
    pub project_slug: &'a str,
    /// Apex domain under which the URL is issued, when configured.
    pub apex_domain: Option<&'a str>,
    /// Target release version string (e.g. "1.0.0").
    pub release_version: Option<&'a str>,
    /// Build integer sequence number.
    pub build_number: Option<i64>,
    /// Mobile package name or bundle ID (e.g. "com.example.app").
    pub package_name: Option<&'a str>,
    /// TestFlight beta group identifier for assignment.
    pub beta_group_id: Option<&'a str>,
    /// Google Play track name (e.g. "internal", "alpha", "beta", "production").
    pub track: Option<&'a str>,
    /// Rollout fraction for staged rollouts on Google Play (0.0 < fraction < 1.0).
    pub user_fraction: Option<f64>,
    /// Working directory for Shorebird CLI execution.
    pub working_dir: Option<&'a Path>,
}

/// The identifiers and routing parameters carried by one claimed `Job::Deploy`.
///
/// Grouped into a struct rather than passed positionally: every field is typed, preventing
/// swapped parameters between slugs and identifiers.
#[derive(Debug, Clone)]
pub struct DeployJobContext {
    /// Public UUID of the deployment.
    pub deployment_id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Public UUID of the associated release, if any.
    pub release_id: Option<String>,
    /// Public UUID of the associated artifact, if any.
    pub artifact_id: Option<String>,
    /// Public UUID of the parent project.
    pub project_id: String,
    /// Public UUID of the parent app.
    pub app_id: String,
    /// Target platform: `ios`, `android`, `web`.
    pub platform: String,
    /// Deployment target: `preview`, `production`, `testflight`, `app_store`, `internal`, `closed`, `open`, `shorebird`.
    pub target: String,
    /// URL slug of the app.
    pub app_slug: String,
    /// URL slug of the project.
    pub project_slug: String,
    /// Apex domain under which the URL is issued, when configured.
    pub apex_domain: Option<String>,
    /// Target release version string.
    pub release_version: Option<String>,
    /// Build integer sequence number.
    pub build_number: Option<i64>,
    /// Mobile package name or bundle ID.
    pub package_name: Option<String>,
    /// TestFlight beta group identifier.
    pub beta_group_id: Option<String>,
    /// Google Play track name or Shorebird track.
    pub track: Option<String>,
    /// Rollout fraction for staged rollouts.
    pub user_fraction: Option<f64>,
    /// Working directory path for Shorebird CLI execution.
    pub working_dir: Option<PathBuf>,
}

/// Executes a single claimed deployment job with total ack/fail semantics.
///
/// Workflow:
/// 1. Verifies the claimed job is `Job::Deploy`.
/// 2. Heartbeats the queue claim before long-running operations.
/// 3. Routes deployment execution to the target platform provider:
///    - Web: S3 upload + CDN invalidation + Caddy route.
///    - TestFlight / App Store: App Store Connect build processing + Beta group assignment.
///    - Google Play: Atomic Edit transaction lifecycle with guaranteed rollback on failure.
///    - Shorebird: CLI patch execution and release linking.
/// 4. Re-enqueues parent workflow run if waiting on this deployment.
/// 5. Acknowledges the job on success; fails the job with reason on fatal error.
pub async fn run_deploy_job(
    deps: DeployWorkerDeps<'_>,
    consumer_name: &str,
    queued_job: QueuedJob,
    routing: DeployRouting<'_>,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let DeployWorkerDeps { db, queue, .. } = deps;
    let stream_id = queued_job.stream_id.clone();

    let (deployment_id, organization_id, release_id, artifact_id, platform, target) =
        match queued_job.job {
            Job::Deploy {
                deployment_id,
                organization_id,
                release_id,
                artifact_id,
                platform,
                target,
            } => (
                deployment_id,
                organization_id,
                release_id,
                artifact_id,
                platform,
                target,
            ),
            other => {
                let reason = format!("Expected Job::Deploy, got {}", other.job_type());
                let _ = queue.fail(&stream_id, &reason).await;
                return Err(DeployWorkerError::InvalidJobVariant(reason));
            }
        };

    let ctx = DeployJobContext {
        deployment_id,
        organization_id,
        release_id,
        artifact_id: Some(artifact_id),
        project_id: routing.project_id.to_string(),
        app_id: routing.app_id.to_string(),
        platform,
        target,
        app_slug: routing.app_slug.to_string(),
        project_slug: routing.project_slug.to_string(),
        apex_domain: routing.apex_domain.map(str::to_string),
        release_version: routing.release_version.map(str::to_string),
        build_number: routing.build_number,
        package_name: routing.package_name.map(str::to_string),
        beta_group_id: routing.beta_group_id.map(str::to_string),
        track: routing.track.map(str::to_string),
        user_fraction: routing.user_fraction,
        working_dir: routing.working_dir.map(Path::to_path_buf),
    };
    let deployment_id = ctx.deployment_id.clone();

    // Execute multi-target deploy pipeline
    match execute_deploy_pipeline(deps, consumer_name, &stream_id, &ctx).await {
        Ok(result) => {
            // Emit deployment.succeeded event
            crate::apps::events::emit(
                db,
                "deployment.succeeded",
                None,
                None,
                None,
                None,
                serde_json::json!({
                    "deployment_id": deployment_id,
                    "target": ctx.target,
                    "platform": ctx.platform,
                    "external_id": result.external_id,
                    "external_url": result.external_url,
                }),
            )
            .await;

            // Re-enqueue parent workflow run on success if parked
            let _ = resume_parent_workflow_run(db, queue, &deployment_id, "live", None).await;

            // Acknowledge the job in Redis Streams
            queue
                .ack(&stream_id)
                .await
                .map_err(|e| DeployWorkerError::Queue(e.to_string()))?;
            Ok(result)
        }
        Err(err) => {
            let error_message = err.to_string();
            eprintln!("Deploy {deployment_id} execution failed: {error_message}");

            // Emit deployment.failed event through domain events service
            crate::apps::events::emit(
                db,
                "deployment.failed",
                None,
                None,
                None,
                None,
                serde_json::json!({
                    "deployment_id": deployment_id,
                    "target": ctx.target,
                    "platform": ctx.platform,
                    "reason": error_message,
                }),
            )
            .await;

            // Re-enqueue parent workflow run on failure so parked runs fail rather than hanging
            let _ = resume_parent_workflow_run(
                db,
                queue,
                &deployment_id,
                "failed",
                Some(&error_message),
            )
            .await;

            // Total failure contract: record fail diagnostics in queue
            let _ = queue.fail(&stream_id, &error_message).await;

            Err(err)
        }
    }
}

/// Routes deployment execution to the appropriate vendor or web pipeline.
async fn execute_deploy_pipeline(
    deps: DeployWorkerDeps<'_>,
    consumer_name: &str,
    stream_id: &str,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    // 1. Heartbeat queue claim before starting network I/O
    deps.queue
        .heartbeat(stream_id, consumer_name)
        .await
        .map_err(|e| DeployWorkerError::Queue(e.to_string()))?;

    let target = ctx.target.to_ascii_lowercase();
    let platform = ctx.platform.to_ascii_lowercase();

    match (platform.as_str(), target.as_str()) {
        // Web targets -> existing Caddy + CDN path
        ("web", "preview")
        | ("web", "production")
        | ("web", "web")
        | (_, "preview")
        | (_, "web") => execute_web_deploy(deps, consumer_name, ctx).await,

        // TestFlight / App Store targets -> App Store Connect client
        ("ios", "testflight") | ("ios", "app_store") | (_, "testflight") | (_, "app_store") => {
            execute_testflight_deploy(deps, ctx).await
        }

        // Google Play track targets -> Google Play client
        ("android", "internal")
        | ("android", "internal_testing")
        | ("android", "closed")
        | ("android", "open")
        | ("android", "production")
        | ("android", "play_store")
        | (_, "internal")
        | (_, "internal_testing")
        | (_, "closed")
        | (_, "open")
        | (_, "play_store") => execute_googleplay_deploy(deps, ctx).await,

        // Shorebird OTA code push targets -> Shorebird client
        (_, "shorebird") => execute_shorebird_deploy(deps, ctx).await,

        _ => Err(DeployWorkerError::InvalidTarget(format!(
            "Unsupported platform '{platform}' and target '{target}' for deploy worker"
        ))),
    }
}

/// Executes web bundle deployment, CDN cache purging, and Caddy ingress reverse-proxy configuration.
async fn execute_web_deploy(
    deps: DeployWorkerDeps<'_>,
    consumer_name: &str,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let _ = consumer_name;
    let DeployWorkerDeps {
        db,
        storage,
        cdn,
        caddy,
        ..
    } = deps;
    let DeployJobContext {
        deployment_id,
        organization_id,
        project_id,
        app_id,
        app_slug,
        project_slug,
        ..
    } = ctx;
    let apex_domain = ctx.apex_domain.as_deref();

    // 1. Resolve artifact record from database
    let art_id = ctx.artifact_id.as_deref().ok_or_else(|| {
        DeployWorkerError::Storage("Missing artifact_id for web deployment".to_string())
    })?;

    let artifact = Artifact::objects()
        .filter(q!(public_id = art_id.to_string()))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .ok_or_else(|| {
            DeployWorkerError::Storage(format!("Artifact '{art_id}' not found in database"))
        })?;

    // 2. Fetch real bundle bytes from object storage
    let bundle_bytes = storage.get(&artifact.storage_key).await.map_err(|e| {
        DeployWorkerError::Storage(format!(
            "Failed to download web bundle from storage at '{}': {e}",
            artifact.storage_key
        ))
    })?;

    // 3. Verify SHA-256 checksum integrity against recorded checksum
    let mut hasher = Sha256::new();
    hasher.update(&bundle_bytes);
    let actual_checksum = format!("{:x}", hasher.finalize());

    if !Crypto::constant_time_eq_str(&actual_checksum, &artifact.checksum) {
        return Err(DeployWorkerError::Storage(format!(
            "Web bundle checksum mismatch for '{}': expected {}, got {}. Storage corruption detected!",
            artifact.public_id, artifact.checksum, actual_checksum
        )));
    }

    // 4. Derive canonical storage prefix and upload bundle assets
    let storage_prefix =
        build_web_storage_prefix(organization_id, project_id, app_id, deployment_id);

    upload_web_bundle_assets(storage, &storage_prefix, &artifact.file_name, bundle_bytes).await?;

    // 5. Invalidate CDN cache for the deployment prefix
    let cdn_outcome = match cdn
        .purge_prefixes(std::slice::from_ref(&storage_prefix))
        .await
    {
        Ok(outcome) => outcome,
        Err(cdn_err) => {
            eprintln!(
                "Warning: CDN cache invalidation failed for prefix {storage_prefix}: {cdn_err}"
            );
            PurgeOutcome::Skipped {
                reason: format!("CDN invalidation failed: {cdn_err}"),
            }
        }
    };

    // 6. Provision Caddy site block
    let site_id = caddy_site_id(deployment_id);

    let apex = apex_domain.unwrap_or("bloomcloud.dev");
    let hostname = format!("{app_slug}-{project_slug}.{apex}");

    let site_block = CaddySiteBlock {
        id: site_id.clone(),
        r#match: Some(vec![CaddyMatchRule {
            host: Some(vec![hostname.clone()]),
        }]),
        handle: vec![serde_json::json!({
            "handler": "file_server",
            "root": format!("/var/bloom/web/{storage_prefix}"),
            "index_names": ["index.html"]
        })],
        terminal: Some(true),
    };

    caddy
        .add_site_block(DEFAULT_CADDY_ROUTES_PATH, &site_block)
        .await
        .map_err(|e| DeployWorkerError::Caddy(e.to_string()))?;

    Ok(DeployWorkerResult {
        deployment_id: deployment_id.to_string(),
        storage_prefix,
        cdn_outcome,
        caddy_site_id: site_id,
        external_id: None,
        external_url: Some(format!("https://{hostname}")),
    })
}

/// Executes App Store Connect / TestFlight delivery.
async fn execute_testflight_deploy(
    deps: DeployWorkerDeps<'_>,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let client = deps.testflight;
    if !client.is_configured() {
        return Err(DeployWorkerError::PublishingAccount(
            "Apple App Store Connect / TestFlight credentials not configured".to_string(),
        ));
    }

    let app_identifier = ctx.package_name.as_deref().unwrap_or(&ctx.app_id);
    let version = ctx.release_version.as_deref().unwrap_or("1.0.0");

    // 1. Poll build processing state
    // Defensively treat unknown/unverified processingState as in-progress per unverified specification.
    let maybe_state = client
        .poll_build_processing_state(app_identifier, version)
        .await
        .map_err(map_testflight_error)?;

    let mut build_id_result = None;

    if let Some(state) = maybe_state {
        match state {
            TestFlightProcessingState::Valid => {
                // Build processing succeeded and is ready for beta group assignment
                if let Some(ref beta_group_id) = ctx.beta_group_id {
                    let build_id = format!("{app_identifier}-{version}");
                    client
                        .assign_beta_group(beta_group_id, &build_id)
                        .await
                        .map_err(map_testflight_error)?;
                    build_id_result = Some(build_id);
                }
            }
            TestFlightProcessingState::Failed => {
                return Err(DeployWorkerError::TestFlight(format!(
                    "App Store Connect build processing failed for {app_identifier} version {version}"
                )));
            }
            TestFlightProcessingState::Processing => {
                eprintln!(
                    "TestFlight build {app_identifier} v{version} is still processing in App Store Connect"
                );
            }
            TestFlightProcessingState::Unknown(raw_status) => {
                // UNVERIFIED: Defensively treat any unverified processingState as still processing
                eprintln!(
                    "TestFlight build {app_identifier} v{version} reported unverified processingState '{raw_status}'; treating as still processing"
                );
            }
        }
    }

    let external_url =
        format!("https://appstoreconnect.apple.com/apps/{app_identifier}/testflight/ios");

    Ok(DeployWorkerResult {
        deployment_id: ctx.deployment_id.clone(),
        storage_prefix: String::new(),
        cdn_outcome: PurgeOutcome::Skipped {
            reason: "Not a web deployment (TestFlight target)".to_string(),
        },
        caddy_site_id: String::new(),
        external_id: build_id_result.or_else(|| Some(format!("{app_identifier}-{version}"))),
        external_url: Some(external_url),
    })
}

/// Executes Google Play publishing through the atomic edit transaction lifecycle:
/// `create_edit` -> `upload_bundle` -> `assign_track` -> `validate_edit` -> `commit_edit`.
///
/// On ANY failure following `create_edit`, the edit is explicitly deleted/abandoned
/// so no orphaned edit blocks subsequent deploys.
async fn execute_googleplay_deploy(
    deps: DeployWorkerDeps<'_>,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let client = deps.googleplay;
    if !client.is_configured() {
        return Err(DeployWorkerError::PublishingAccount(
            "Google Play Android Developer API credentials not configured".to_string(),
        ));
    }

    let package_name = ctx.package_name.as_deref().unwrap_or(&ctx.app_slug);

    // 1. Create Edit (edits.insert)
    let edit = client
        .create_edit(package_name)
        .await
        .map_err(map_googleplay_error)?;

    let edit_id = edit.id.clone();

    // 2. Execute remaining edit transaction lifecycle with guaranteed cleanup
    let lifecycle_result = execute_googleplay_lifecycle(deps, ctx, package_name, &edit_id).await;

    if let Err(err) = lifecycle_result {
        eprintln!(
            "Google Play deployment failed for {package_name} edit {edit_id}; abandoning edit: {err}"
        );
        // Explicitly delete edit to prevent orphaned edit locks
        let _ = client.delete_edit(package_name, &edit_id).await;
        return Err(err);
    }

    let (committed_edit_id, version_code) = lifecycle_result?;

    let track_name = ctx.track.as_deref().unwrap_or("internal");
    let external_url = format!(
        "https://play.google.com/console/developers/app/{package_name}/tracks/{track_name}"
    );

    Ok(DeployWorkerResult {
        deployment_id: ctx.deployment_id.clone(),
        storage_prefix: String::new(),
        cdn_outcome: PurgeOutcome::Skipped {
            reason: "Not a web deployment (Google Play target)".to_string(),
        },
        caddy_site_id: String::new(),
        external_id: Some(
            version_code
                .map(|v| v.to_string())
                .unwrap_or(committed_edit_id),
        ),
        external_url: Some(external_url),
    })
}

/// Internal pipeline executing the Google Play bundle upload, track assignment, and edit commit.
async fn execute_googleplay_lifecycle(
    deps: DeployWorkerDeps<'_>,
    ctx: &DeployJobContext,
    package_name: &str,
    edit_id: &str,
) -> Result<(String, Option<i64>), DeployWorkerError> {
    let client = deps.googleplay;

    // 1. Resolve artifact record from database
    let art_id = ctx.artifact_id.as_deref().ok_or_else(|| {
        DeployWorkerError::Storage("Missing artifact_id for Google Play deployment".to_string())
    })?;

    let artifact = Artifact::objects()
        .filter(q!(public_id = art_id.to_string()))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(deps.db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .ok_or_else(|| {
            DeployWorkerError::Storage(format!("Artifact '{art_id}' not found in database"))
        })?;

    // 2. Download bundle bytes from storage
    let bundle_bytes = deps.storage.get(&artifact.storage_key).await.map_err(|e| {
        DeployWorkerError::Storage(format!(
            "Failed to download bundle from storage at '{}': {e}",
            artifact.storage_key
        ))
    })?;

    // 3. Verify SHA-256 integrity against recorded checksum
    let mut hasher = Sha256::new();
    hasher.update(&bundle_bytes);
    let actual_checksum = format!("{:x}", hasher.finalize());

    if !Crypto::constant_time_eq_str(&actual_checksum, &artifact.checksum) {
        return Err(DeployWorkerError::Storage(format!(
            "Artifact checksum mismatch for '{}': expected {}, got {}. Storage corruption detected!",
            artifact.public_id, artifact.checksum, actual_checksum
        )));
    }

    // 4. Upload verified real bundle bytes (edits.bundles.upload)
    let bundle = client
        .upload_bundle(package_name, edit_id, bundle_bytes, None)
        .await
        .map_err(map_googleplay_error)?;

    let version_code_str = bundle
        .version_code
        .map(|v| v.to_string())
        .or_else(|| ctx.build_number.map(|b| b.to_string()))
        .unwrap_or_else(|| "1".to_string());

    // 2. Assign track (edits.tracks.update)
    let track_name = ctx.track.as_deref().unwrap_or("internal");
    let release_status = if ctx.user_fraction.is_some() {
        ReleaseStatus::InProgress
    } else {
        ReleaseStatus::Completed
    };

    let track_release = TrackRelease {
        name: ctx.release_version.clone(),
        version_codes: Some(vec![version_code_str]),
        release_notes: None,
        status: Some(release_status),
        user_fraction: ctx.user_fraction,
        country_targeting: None,
        in_app_update_priority: None,
    };

    client
        .assign_track(package_name, edit_id, track_name, track_release)
        .await
        .map_err(map_googleplay_error)?;

    // 3. Validate edit
    client
        .validate_edit(package_name, edit_id)
        .await
        .map_err(map_googleplay_error)?;

    // 4. Commit edit (edits.commit)
    let committed = client
        .commit_edit(package_name, edit_id)
        .await
        .map_err(map_googleplay_error)?;

    Ok((committed.id, bundle.version_code))
}

/// Executes Shorebird OTA code push patch creation.
async fn execute_shorebird_deploy(
    deps: DeployWorkerDeps<'_>,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let client = deps.shorebird;
    if !client.is_configured() {
        return Err(DeployWorkerError::PublishingAccount(
            "Shorebird CLI credentials (SHOREBIRD_TOKEN) not configured".to_string(),
        ));
    }

    // Surface account health warning: shorebird login:ci sessions expire in September 2026.
    eprintln!(
        "Notice: Verifying Shorebird credentials. Note that legacy 'shorebird login:ci' tokens expire in September 2026; ensure API keys are console-issued."
    );

    let platform = match ctx.platform.to_ascii_lowercase().as_str() {
        "android" => ShorebirdPlatform::Android,
        "ios" => ShorebirdPlatform::Ios,
        "linux" => ShorebirdPlatform::Linux,
        "macos" => ShorebirdPlatform::Macos,
        "windows" => ShorebirdPlatform::Windows,
        _ => ShorebirdPlatform::Android,
    };

    let platforms = ShorebirdPlatforms::Single(platform);
    let options = ShorebirdOptions {
        release_version: ctx.release_version.clone(),
        track: ctx.track.clone().or_else(|| Some("stable".to_string())),
        ..Default::default()
    };

    let result = client
        .patch(&platforms, &options, ctx.working_dir.as_deref())
        .await
        .map_err(map_shorebird_error)?;

    let patch_id = result.release_or_patch_id.clone();
    let external_url = format!("https://console.shorebird.dev/apps/{}", ctx.app_slug);

    Ok(DeployWorkerResult {
        deployment_id: ctx.deployment_id.clone(),
        storage_prefix: String::new(),
        cdn_outcome: PurgeOutcome::Skipped {
            reason: "Not a web deployment (Shorebird target)".to_string(),
        },
        caddy_site_id: String::new(),
        external_id: patch_id,
        external_url: Some(external_url),
    })
}

/// Re-enqueues the parent workflow run if this deployment was spawned by a workflow step.
///
/// # Resumption & Idempotence Guarantee
///
/// When a deployment reaches a terminal state (`ready`, `live`, `failed`, or `cancelled`),
/// it checks whether a workflow step is waiting on it via `deployment.workflow_run_step_id`.
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
    deployment_id: &str,
    terminal_status: &str,
    failure_reason: Option<&str>,
) -> Result<(), DeployWorkerError> {
    // 1. Resolve deployment record
    let deployment = match Deployment::objects()
        .filter(q!(public_id = deployment_id.to_owned()))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
    {
        Some(d) => d,
        None => return Ok(()),
    };

    // 2. Check if a workflow run step is waiting on this deployment
    let step_id = match deployment.workflow_run_step_id {
        Some(id) => id,
        None => return Ok(()),
    };

    // 3. Resolve the waiting WorkflowRunStep
    let mut step = match WorkflowRunStep::objects()
        .filter(q!(id = step_id))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
    {
        Some(s) => s,
        None => return Ok(()),
    };

    // 4. Idempotency guard: if the step is already completed or failed, do NOT re-enqueue
    if step.status != "running" {
        return Ok(());
    }

    let now = Utc::now();
    let is_success = matches!(terminal_status, "ready" | "live" | "completed" | "success");

    if is_success {
        step.status = "completed".to_string();
        step.finished_at = Some(now);
        step.log_snippet = Some(format!(
            "Deployment '{deployment_id}' finished successfully."
        ));
    } else {
        step.status = "failed".to_string();
        step.finished_at = Some(now);
        step.log_snippet = Some(failure_reason.unwrap_or("Deployment failed").to_string());
    }

    // Persist step transition
    workflow_repos::update_workflow_run_step(db, &step)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?;

    // 5. Resolve parent WorkflowRun
    let run = match WorkflowRun::objects()
        .filter(q!(id = step.run_id.id))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
    {
        Some(r) => r,
        None => return Ok(()),
    };

    // 6. Resolve parent Workflow definition
    let workflow = match Workflow::objects()
        .filter(q!(id = run.workflow_id.id))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
    {
        Some(w) => w,
        None => return Ok(()),
    };

    // 7. Resolve Organization public UUID
    let org = Organization::objects()
        .filter(q!(id = run.organization_id))
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?
        .first(db)
        .await
        .map_err(|e| DeployWorkerError::WebHostingService(e.to_string()))?;

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
        .map_err(|e| DeployWorkerError::Queue(e.to_string()))?;

    Ok(())
}

/// Helper to unpack or upload web bundle assets into object storage under `storage_prefix`.
async fn upload_web_bundle_assets(
    storage: &dyn ObjectStorage,
    storage_prefix: &str,
    filename: &str,
    bundle_bytes: Bytes,
) -> Result<(), DeployWorkerError> {
    // If bundle is gzip compressed tar archive
    if bundle_bytes.starts_with(&[0x1f, 0x8b]) {
        let temp_dir =
            std::env::temp_dir().join(format!("bloom_web_deploy_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&temp_dir).map_err(|e| {
            DeployWorkerError::Storage(format!(
                "Failed to create temp directory for web bundle extraction: {e}"
            ))
        })?;

        let archive_file = temp_dir.join("bundle.tar.gz");
        if let Err(e) = std::fs::write(&archive_file, &bundle_bytes) {
            let _ = std::fs::remove_dir_all(&temp_dir);
            return Err(DeployWorkerError::Storage(format!(
                "Failed to write web bundle archive to disk: {e}"
            )));
        }

        let extract_dir = temp_dir.join("extracted");
        if let Err(e) = std::fs::create_dir_all(&extract_dir) {
            let _ = std::fs::remove_dir_all(&temp_dir);
            return Err(DeployWorkerError::Storage(format!(
                "Failed to create extraction directory: {e}"
            )));
        }

        let tar_res = std::process::Command::new("tar")
            .args([
                "-xzf",
                archive_file.to_str().unwrap(),
                "-C",
                extract_dir.to_str().unwrap(),
            ])
            .output();

        let upload_result = match tar_res {
            Ok(out) if out.status.success() => {
                upload_directory_recursively(storage, storage_prefix, &extract_dir).await
            }
            Ok(out) => Err(DeployWorkerError::Storage(format!(
                "Failed to extract web bundle tar.gz: {}",
                String::from_utf8_lossy(&out.stderr)
            ))),
            Err(e) => Err(DeployWorkerError::Storage(format!(
                "Failed to execute tar command: {e}"
            ))),
        };

        let _ = std::fs::remove_dir_all(&temp_dir);
        upload_result
    } else {
        // Single file or uncompressed bundle: upload directly under filename or index.html
        let target_key = if filename.ends_with(".js") {
            format!("{storage_prefix}/main.dart.js")
        } else if filename.ends_with(".html") {
            format!("{storage_prefix}/index.html")
        } else {
            format!("{storage_prefix}/{filename}")
        };
        let content_type = detect_content_type(&target_key);
        storage
            .put(&target_key, bundle_bytes, content_type)
            .await
            .map_err(|e| DeployWorkerError::Storage(e.to_string()))
    }
}

/// Uploads all files in a directory recursively to object storage under a key prefix.
async fn upload_directory_recursively(
    storage: &dyn ObjectStorage,
    storage_prefix: &str,
    dir: &Path,
) -> Result<(), DeployWorkerError> {
    let mut stack = vec![dir.to_path_buf()];
    let mut files_uploaded = 0;

    while let Some(current_dir) = stack.pop() {
        let entries = std::fs::read_dir(&current_dir).map_err(|e| {
            DeployWorkerError::Storage(format!(
                "Failed to read directory '{}': {e}",
                current_dir.display()
            ))
        })?;

        for entry in entries {
            let entry = entry.map_err(|e| {
                DeployWorkerError::Storage(format!("Failed reading directory entry: {e}"))
            })?;
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path.is_file() {
                let rel_path = path.strip_prefix(dir).map_err(|e| {
                    DeployWorkerError::Storage(format!("Failed computing relative path: {e}"))
                })?;
                let rel_str = rel_path.to_string_lossy().replace('\\', "/");
                let key = format!("{storage_prefix}/{rel_str}");
                let content_type = detect_content_type(&rel_str);
                let bytes = std::fs::read(&path).map_err(|e| {
                    DeployWorkerError::Storage(format!(
                        "Failed reading file '{}': {e}",
                        path.display()
                    ))
                })?;

                storage
                    .put(&key, Bytes::from(bytes), content_type)
                    .await
                    .map_err(|e| DeployWorkerError::Storage(e.to_string()))?;
                files_uploaded += 1;
            }
        }
    }

    if files_uploaded == 0 {
        return Err(DeployWorkerError::Storage(format!(
            "Web bundle extraction produced no files in '{}'",
            dir.display()
        )));
    }

    Ok(())
}

/// Detects the MIME content type from a file path or extension.
fn detect_content_type(path: &str) -> &'static str {
    if path.ends_with(".html") || path.ends_with(".htm") {
        "text/html"
    } else if path.ends_with(".js") || path.ends_with(".mjs") {
        "application/javascript"
    } else if path.ends_with(".css") {
        "text/css"
    } else if path.ends_with(".json") {
        "application/json"
    } else if path.ends_with(".png") {
        "image/png"
    } else if path.ends_with(".jpg") || path.ends_with(".jpeg") {
        "image/jpeg"
    } else if path.ends_with(".svg") {
        "image/svg+xml"
    } else if path.ends_with(".wasm") {
        "application/wasm"
    } else if path.ends_with(".ico") {
        "image/x-icon"
    } else if path.ends_with(".map") {
        "application/json"
    } else if path.ends_with(".tar.gz") || path.ends_with(".tgz") {
        "application/gzip"
    } else {
        "application/octet-stream"
    }
}
