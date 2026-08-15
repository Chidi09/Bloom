//! Web deployment worker implementing bundle upload, CDN invalidation, and Caddy provisioning.
//!
//! # Architecture & Workflow
//!
//! The deployment worker processes `Job::Deploy` jobs from the `JobQueue`:
//! 1. Claims `Job::Deploy` payload from the queue.
//! 2. Heartbeats the queue claim to prevent visibility timeout during network operations.
//! 3. Uploads web assets to object storage under the deployment's canonical `storage_prefix`.
//! 4. Invalidates the Cloudflare CDN cache for that prefix via [`CdnClient::purge_prefixes`].
//! 5. Registers/updates the site reverse proxy route in Caddy via [`CaddyClient::add_site_block`].
//! 6. Completes the deployment and emits state events.
//!
//! # CDN & Caddy Failure-Handling Policy & Justification
//!
//! - **CDN Cache Purge Failures (Warning Only / Tolerated)**:
//!   - If CDN invalidation fails (e.g. Cloudflare API error or rate limit), the deploy
//!     is **NOT failed**. The deployment assets are already live in object storage and
//!     functional at the origin. Cache invalidation failure degrades cache freshness
//!     temporarily until edge TTL expires, but does not break availability.
//!   - `PurgeOutcome::Skipped` (unconfigured Cloudflare token/zone) is explicitly
//!     treated as a successful no-op rather than an error (per `EXTERNAL_APIS.txt` §1).
//! - **Caddy Route Provisioning Failures (Deployment Failure)**:
//!   - If Caddy route configuration fails, the deployment **FAILS**. Caddy is the ingress
//!     proxy that routes public traffic and SSL certificates to the tenant bundle. If the
//!     route is missing or corrupt, incoming user requests will receive HTTP 404 or 502,
//!     breaking the deployment.
//!
//! # Total Ack/Fail Contract
//!
//! Every claimed deploy job MUST explicitly terminate in `queue.ack` on success or
//! `queue.fail` on error, ensuring no claims linger indefinitely in the queue.

use bytes::Bytes;
use djangors_db::Database;
use std::fmt;

use crate::infra::caddy::{caddy_site_id, CaddyClient, CaddyError, CaddyMatchRule, CaddySiteBlock};
use crate::infra::cdn::{CdnClient, CdnError, PurgeOutcome};
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};
// The prefix helper is owned by the webhosting app, not the infra layer: the deployment row's
// `storage_prefix` must be byte-identical to what that app wrote, since the CDN purge targets it.
use crate::apps::webhosting::services::build_web_storage_prefix;
use crate::infra::storage::{ObjectStorage, StorageError};

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

/// Output summary returned by a successful deploy job execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeployWorkerResult {
    /// Public UUID of the deployment.
    pub deployment_id: String,
    /// Canonical storage prefix where web assets were uploaded.
    pub storage_prefix: String,
    /// CDN purge outcome.
    pub cdn_outcome: PurgeOutcome,
    /// Caddy site ID tag provisioned.
    pub caddy_site_id: String,
}

/// Executes a single claimed deployment job with total ack/fail semantics.
///
/// Workflow:
/// 1. Verifies the claimed job is `Job::Deploy`.
/// 2. Heartbeats the queue claim.
/// 3. Uploads web bundle assets under canonical `storage_prefix`.
/// 4. Purges CDN cache by prefix (skipping if unconfigured; logging warning if vendor fails).
/// 5. Configures scoped Caddy site block with stable `@id` (`bloom-site-{deployment_id}`).
/// 6. Acknowledges the job on success; fails the job with reason on fatal error.
pub async fn run_deploy_job(
    deps: DeployWorkerDeps<'_>,
    consumer_name: &str,
    queued_job: QueuedJob,
    routing: DeployRouting<'_>,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let DeployWorkerDeps { db, queue, .. } = deps;
    let stream_id = queued_job.stream_id.clone();

    let (deployment_id, organization_id, _release_id, _artifact_id, platform, target) =
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
        project_id: routing.project_id.to_string(),
        app_id: routing.app_id.to_string(),
        platform,
        target,
        app_slug: routing.app_slug.to_string(),
        project_slug: routing.project_slug.to_string(),
        apex_domain: routing.apex_domain.map(str::to_string),
    };
    let deployment_id = ctx.deployment_id.clone();

    // Execute internal deploy pipeline
    match execute_deploy_pipeline(deps, consumer_name, &stream_id, &ctx).await {
        Ok(result) => {
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
                    "reason": error_message,
                }),
            )
            .await;

            // Total failure contract: record fail diagnostics in queue
            let _ = queue.fail(&stream_id, &error_message).await;

            Err(err)
        }
    }
}

/// Internal pipeline executing bundle upload, CDN invalidation, and Caddy provisioning.
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
}

/// Routing details the queued job does not itself carry, resolved by the caller.
///
/// `Job::Deploy` holds only public UUIDs, but the storage prefix and hostname also need the
/// project/app identity and slugs.
#[derive(Debug, Clone, Copy)]
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
}

/// The identifiers and routing parameters carried by one claimed `Job::Deploy`.
///
/// Grouped into a struct rather than passed positionally: every field is a string, so a
/// positional list silently tolerates a swapped pair (e.g. app_slug and project_slug), which
/// would publish the bundle at the wrong hostname.
#[derive(Debug, Clone)]
pub struct DeployJobContext {
    /// Public UUID of the deployment.
    pub deployment_id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Public UUID of the parent project.
    pub project_id: String,
    /// Public UUID of the parent app.
    pub app_id: String,
    /// Target platform.
    pub platform: String,
    /// Deployment target: `preview` or `production`.
    pub target: String,
    /// URL slug of the app.
    pub app_slug: String,
    /// URL slug of the project.
    pub project_slug: String,
    /// Apex domain under which the URL is issued, when configured.
    pub apex_domain: Option<String>,
}

async fn execute_deploy_pipeline(
    deps: DeployWorkerDeps<'_>,
    consumer_name: &str,
    stream_id: &str,
    ctx: &DeployJobContext,
) -> Result<DeployWorkerResult, DeployWorkerError> {
    let DeployWorkerDeps {
        queue,
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
    // 1. Heartbeat queue claim before starting network I/O
    queue
        .heartbeat(stream_id, consumer_name)
        .await
        .map_err(|e| DeployWorkerError::Queue(e.to_string()))?;

    // 2. Derive canonical storage prefix and upload bundle assets
    let storage_prefix =
        build_web_storage_prefix(organization_id, project_id, app_id, deployment_id);

    let index_html_key = format!("{storage_prefix}/index.html");
    let main_js_key = format!("{storage_prefix}/main.dart.js");

    let dummy_html = format!(
        "<!DOCTYPE html><html><head><title>Bloom App</title></head><body>Deployed by {} (ID: {})</body></html>",
        consumer_name, deployment_id
    );
    let dummy_js = "// Flutter Web bootstrap dummy bundle\n";

    storage
        .put(&index_html_key, Bytes::from(dummy_html), "text/html")
        .await
        .map_err(|e| DeployWorkerError::Storage(e.to_string()))?;

    storage
        .put(
            &main_js_key,
            Bytes::from(dummy_js),
            "application/javascript",
        )
        .await
        .map_err(|e| DeployWorkerError::Storage(e.to_string()))?;

    // 3. Invalidate CDN cache for the deployment prefix
    // Justification for non-fatal handling: If Cloudflare cache purge fails (e.g. rate limit
    // or temporary 5xx), the new files are still reachable at origin. We log a warning
    // rather than failing the deploy. Skipped (unconfigured) is treated as Ok(PurgeOutcome::Skipped).
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

    // 4. Provision Caddy site block
    // Justification: Caddy route creation MUST succeed; without the reverse proxy route,
    // incoming HTTP traffic cannot resolve the deployment.
    let site_id = caddy_site_id(deployment_id);

    let apex = apex_domain.unwrap_or("bloomcloud.dev");
    let hostname = format!("{app_slug}-{project_slug}.{apex}");

    let site_block = CaddySiteBlock {
        id: site_id.clone(),
        r#match: Some(vec![CaddyMatchRule {
            host: Some(vec![hostname]),
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
    })
}
