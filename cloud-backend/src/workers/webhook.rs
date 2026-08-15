//! Webhook worker validating signatures, deduplicating deliveries, and triggering builds.
//!
//! # Architecture & Security Boundary
//!
//! Webhook deliveries from Git providers (GitHub, GitLab, Bitbucket) serve as the ingress
//! trigger for automated CI/CD builds and preview deployments.
//!
//! Because webhook endpoints receive unauthenticated HTTP traffic directly from external networks,
//! this module acts as a strict **security boundary**:
//!
//! 1. **Cryptographic Signature Verification**:
//!    - GitHub deliveries MUST include the `X-Hub-Signature-256` header formatted as `"sha256=" + hex_digest`.
//!    - Signatures are computed as `HMAC-SHA256(secret, raw_body_bytes)`.
//!    - **The raw request body bytes (`&[u8]`) are verified directly.** Deserializing and re-serializing JSON
//!      before verification is forbidden because whitespace or key-order differences invalidate signatures.
//!    - Digests are compared in **constant time** via [`Crypto::constant_time_eq`] to prevent timing attacks.
//!    - Missing signatures, absent secrets, or signature mismatches are **rejected immediately**
//!      before performing any database writes or queue interactions.
//!
//! 2. **Unverified Providers**:
//!    - GitLab and Bitbucket signature schemes are not independently verified against live vendor specifications.
//!    - Per `EXTERNAL_APIS.txt` §6, unverified provider deliveries are **safely rejected** rather than accepted unverified.
//!
//! 3. **Idempotency & Deduplication**:
//!    - Deliveries are uniquely identified by the `X-GitHub-Delivery` GUID.
//!    - Replaying a delivery GUID is a no-op and will not queue duplicate build jobs.
//!
//! 4. **Total Ack/Fail Contract**:
//!    - Every claimed [`Job::Webhook`] ends explicitly in either `queue.ack(stream_id)` on success
//!      or `queue.fail(stream_id, reason)` on fatal error.

use std::collections::HashSet;
use std::fmt;
use std::sync::Arc;

use djangors_db::Database;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::infra::crypto::Crypto;
use crate::infra::queue::{Job, JobQueue, QueueError, QueuedJob};

/// Canonical GitHub webhook header names.
/// Authorised by EXTERNAL_APIS.txt lines 196-203.
pub const HEADER_GITHUB_HOOK_ID: &str = "X-GitHub-Hook-ID";
/// Canonical GitHub event name header.
pub const HEADER_GITHUB_EVENT: &str = "X-GitHub-Event";
/// Canonical GitHub delivery GUID header used for deduplication.
pub const HEADER_GITHUB_DELIVERY: &str = "X-GitHub-Delivery";
/// Canonical GitHub HMAC-SHA256 signature header.
pub const HEADER_HUB_SIGNATURE_256: &str = "X-Hub-Signature-256";
/// Canonical User-Agent prefix for GitHub webhooks.
pub const GITHUB_USER_AGENT_PREFIX: &str = "GitHub-Hookshot/";

/// Supported Git webhook provider identifiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum WebhookProvider {
    /// GitHub App or repository webhook.
    GitHub,
    /// GitLab webhook.
    GitLab,
    /// Bitbucket webhook.
    BitBucket,
}

impl WebhookProvider {
    /// Returns the provider discriminator string.
    pub fn as_str(&self) -> &'static str {
        match self {
            WebhookProvider::GitHub => "github",
            WebhookProvider::GitLab => "gitlab",
            WebhookProvider::BitBucket => "bitbucket",
        }
    }

    /// Parses a provider string into a [`WebhookProvider`] variant.
    pub fn from_str_opt(s: &str) -> Option<Self> {
        match s.trim().to_ascii_lowercase().as_str() {
            "github" => Some(WebhookProvider::GitHub),
            "gitlab" => Some(WebhookProvider::GitLab),
            "bitbucket" => Some(WebhookProvider::BitBucket),
            _ => None,
        }
    }
}

impl fmt::Display for WebhookProvider {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Errors arising during webhook signature verification, deduplication, or execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WebhookError {
    /// Webhook payload was missing the required signature header.
    MissingSignature(String),
    /// Signature header was present but formatted incorrectly (e.g. missing `sha256=` prefix).
    InvalidSignatureFormat(String),
    /// HMAC-SHA256 signature verification failed (digest mismatch).
    SignatureMismatch(String),
    /// Webhook secret is not configured for the target repository or connection.
    MissingSecret(String),
    /// Webhook provider is unverified or unsupported.
    UnverifiedProvider(String),
    /// Delivery GUID has already been processed (duplicate replay).
    DuplicateDelivery(String),
    /// Failed to serialize or deserialize webhook payload JSON.
    Serialization(String),
    /// Job queue push, claim, ack, or fail error.
    Queue(String),
    /// Unexpected job variant claimed by webhook worker.
    InvalidJobVariant(String),
    /// Database or domain event emission error.
    Database(String),
    /// Unrecognised or unsupported webhook event type.
    UnsupportedEvent(String),
}

impl fmt::Display for WebhookError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            WebhookError::MissingSignature(msg) => {
                write!(f, "Webhook signature header missing: {msg}")
            }
            WebhookError::InvalidSignatureFormat(msg) => {
                write!(f, "Invalid webhook signature format: {msg}")
            }
            WebhookError::SignatureMismatch(msg) => {
                write!(f, "Webhook signature verification failed: {msg}")
            }
            WebhookError::MissingSecret(msg) => {
                write!(f, "Webhook secret not configured: {msg}")
            }
            WebhookError::UnverifiedProvider(msg) => {
                write!(f, "Unverified webhook provider rejected: {msg}")
            }
            WebhookError::DuplicateDelivery(id) => {
                write!(
                    f,
                    "Webhook delivery already processed (duplicate GUID): {id}"
                )
            }
            WebhookError::Serialization(msg) => {
                write!(f, "Webhook serialization error: {msg}")
            }
            WebhookError::Queue(msg) => write!(f, "Webhook queue error: {msg}"),
            WebhookError::InvalidJobVariant(msg) => {
                write!(f, "Invalid job variant for webhook worker: {msg}")
            }
            WebhookError::Database(msg) => write!(f, "Webhook database error: {msg}"),
            WebhookError::UnsupportedEvent(msg) => {
                write!(f, "Unsupported webhook event: {msg}")
            }
        }
    }
}

impl std::error::Error for WebhookError {}

impl From<QueueError> for WebhookError {
    fn from(err: QueueError) -> Self {
        WebhookError::Queue(err.to_string())
    }
}

// -----------------------------------------------------------------------------
// Cryptographic HMAC-SHA256 Verification
// -----------------------------------------------------------------------------

/// Computes the RFC 2104 HMAC-SHA256 digest over message bytes using the provided secret key.
///
/// Returns the resulting 32-byte digest formatted as a 64-character lowercase hexadecimal string.
pub fn compute_hmac_sha256_hex(key: &[u8], message: &[u8]) -> String {
    // Delegates to the single HMAC implementation in the crypto layer. This used to carry its
    // own copy of RFC 2104, as did the git_connections app — two independent implementations
    // of the primitive that authenticates every inbound webhook.
    Crypto::hmac_sha256_hex(key, message)
}

/// Verifies a GitHub webhook `X-Hub-Signature-256` header against raw request body bytes.
///
/// # Security Requirements
/// - Header must start with prefix `"sha256="`.
/// - Secret must not be empty.
/// - Comparison is strictly performed in constant time via [`Crypto::constant_time_eq`].
/// - Body bytes must be raw unparsed request payload.
///
/// Authorised by `EXTERNAL_APIS.txt` §6 ("SIGNATURE VERIFICATION").
pub fn verify_github_signature(
    secret: &[u8],
    body_bytes: &[u8],
    signature_header: &str,
) -> Result<bool, WebhookError> {
    if secret.is_empty() {
        return Err(WebhookError::MissingSecret(
            "Webhook secret is empty or not configured".to_string(),
        ));
    }

    let trimmed = signature_header.trim();
    let provided_hex = match trimmed.strip_prefix("sha256=") {
        Some(hex) if !hex.is_empty() => hex.trim(),
        _ => {
            return Err(WebhookError::InvalidSignatureFormat(
                "Signature header must start with 'sha256=' followed by hex digest".to_string(),
            ));
        }
    };

    let expected_hex = compute_hmac_sha256_hex(secret, body_bytes);

    let is_valid = Crypto::constant_time_eq(
        expected_hex.as_bytes(),
        provided_hex.to_ascii_lowercase().as_bytes(),
    );

    Ok(is_valid)
}

/// Dispatches signature verification based on the provider.
///
/// Safely rejects unverified providers (GitLab, Bitbucket) per `EXTERNAL_APIS.txt` §6.
pub fn verify_webhook_delivery(
    provider: WebhookProvider,
    secret: Option<&str>,
    body_bytes: &[u8],
    signature_header: Option<&str>,
) -> Result<(), WebhookError> {
    match provider {
        WebhookProvider::GitHub => {
            let sec = secret.ok_or_else(|| {
                WebhookError::MissingSecret(
                    "No webhook secret configured for GitHub repository".to_string(),
                )
            })?;
            let sig = signature_header.ok_or_else(|| {
                WebhookError::MissingSignature(
                    "Missing X-Hub-Signature-256 header on GitHub webhook".to_string(),
                )
            })?;

            let valid = verify_github_signature(sec.as_bytes(), body_bytes, sig)?;
            if !valid {
                return Err(WebhookError::SignatureMismatch(
                    "HMAC-SHA256 signature does not match expected digest".to_string(),
                ));
            }
            Ok(())
        }
        WebhookProvider::GitLab => {
            // TODO(spec): gitlab signature scheme unverified
            Err(WebhookError::UnverifiedProvider(
                "GitLab webhook signature scheme is unverified per EXTERNAL_APIS.txt §6"
                    .to_string(),
            ))
        }
        WebhookProvider::BitBucket => {
            // TODO(spec): bitbucket signature scheme unverified
            Err(WebhookError::UnverifiedProvider(
                "Bitbucket webhook signature scheme is unverified per EXTERNAL_APIS.txt §6"
                    .to_string(),
            ))
        }
    }
}

// -----------------------------------------------------------------------------
// Deduplication / Idempotency Store
// -----------------------------------------------------------------------------

/// In-memory deduplication set for caching processed webhook delivery IDs.
///
/// Prevents duplicate build trigger execution from replayed deliveries.
#[derive(Clone, Default)]
pub struct WebhookDeduplicator {
    processed: Arc<RwLock<HashSet<String>>>,
}

impl WebhookDeduplicator {
    /// Creates a new empty `WebhookDeduplicator`.
    pub fn new() -> Self {
        Self {
            processed: Arc::new(RwLock::new(HashSet::new())),
        }
    }

    /// Checks if a delivery ID was already processed. If not, records it.
    ///
    /// Returns `true` if the delivery ID is new (successfully recorded),
    /// or `false` if it was already processed (duplicate).
    pub async fn record_if_new(&self, delivery_id: &str) -> bool {
        let mut guard = self.processed.write().await;
        guard.insert(delivery_id.to_string())
    }

    /// Checks if a delivery ID has already been recorded.
    pub async fn is_recorded(&self, delivery_id: &str) -> bool {
        let guard = self.processed.read().await;
        guard.contains(delivery_id)
    }

    /// Clears recorded delivery IDs (used in test fixtures).
    pub async fn clear(&self) {
        let mut guard = self.processed.write().await;
        guard.clear();
    }
}

// -----------------------------------------------------------------------------
// Domain Context & Policy Structs
// -----------------------------------------------------------------------------

/// Git branch deployment policy definition.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WebhookBranchPolicy {
    /// Branch name or glob pattern (e.g. `"main"`, `"staging"`, `"feature/*"`).
    pub pattern: String,
    /// Target environment UUID or name.
    pub environment: String,
    /// Whether matching commits automatically trigger a deployment.
    #[serde(default)]
    pub auto_deploy: bool,
    /// Whether this policy generates an ephemeral preview build.
    #[serde(default)]
    pub preview: bool,
}

impl WebhookBranchPolicy {
    /// Checks if a given branch name matches the configured policy pattern.
    pub fn matches_branch(&self, branch_name: &str) -> bool {
        if self.pattern == "*" {
            return true;
        }
        if let Some(prefix) = self.pattern.strip_suffix('*') {
            return branch_name.starts_with(prefix);
        }
        self.pattern == branch_name
    }
}

/// Metadata summary of a Git connection and target project/app.
///
/// Defined locally because the `git_connections` app is developed in a parallel dispatch.
// TODO(spec): resolve via crate::apps::git_connections once that app lands (same phase).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitConnectionSummary {
    /// Public UUID of the Git connection record.
    pub connection_id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Public UUID of the parent project.
    pub project_id: String,
    /// Public UUID of the parent app.
    pub app_id: String,
    /// Default target environment UUID.
    pub default_environment_id: String,
    /// Provider name (e.g. `"github"`).
    pub provider: String,
    /// Webhook secret used for HMAC verification.
    pub webhook_secret: String,
    /// Target platform for triggered builds (e.g. `"web"`, `"android"`, `"ios"`).
    pub platform: String,
    /// Build profile to use (e.g. `"release"` or `"debug"`).
    pub build_profile: String,
    /// Configured branch deployment policies.
    pub branch_policies: Vec<WebhookBranchPolicy>,
}

/// Outcome of executing a webhook processing job.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WebhookWorkerOutcome {
    /// Webhook processed and a new build was enqueued.
    BuildTriggered {
        /// Public UUID of the triggered build.
        build_id: String,
        /// Commit SHA that triggered the build.
        commit_sha: String,
        /// Branch name if applicable.
        branch: Option<String>,
        /// Target environment public UUID.
        environment_id: String,
    },
    /// Ping event acknowledged without triggering a build.
    PingAcknowledged,
    /// Webhook event was safely ignored (e.g. unsupported event or non-matching branch).
    EventIgnored {
        /// Name of the ignored event or reason.
        reason: String,
    },
    /// Delivery was identified as duplicate and skipped.
    DuplicateIgnored {
        /// Delivery GUID that was ignored.
        delivery_id: String,
    },
}

/// Collaborators and dependencies required for webhook worker execution.
#[derive(Clone)]
pub struct WebhookWorkerDeps<'a> {
    /// Database handle for event recording and state persistence.
    pub db: &'a Database,
    /// Job queue for acknowledging webhook jobs and enqueuing build jobs.
    pub queue: &'a JobQueue,
    /// Deduplication store for delivery ID idempotency.
    pub deduplicator: &'a WebhookDeduplicator,
    /// Resolved Git connection summary.
    pub connection: Option<GitConnectionSummary>,
}

/// Extracts git reference details (branch, commit SHA) from a GitHub `push` payload.
pub fn parse_github_push_payload(payload: &serde_json::Value) -> Option<(String, String, String)> {
    let git_ref = payload.get("ref")?.as_str()?.to_string();
    let branch = git_ref
        .strip_prefix("refs/heads/")
        .unwrap_or(&git_ref)
        .to_string();

    let commit_sha = payload
        .get("after")
        .and_then(|v| v.as_str())
        .or_else(|| {
            payload
                .get("head_commit")
                .and_then(|c| c.get("id"))
                .and_then(|v| v.as_str())
        })?
        .to_string();

    let repo_name = payload
        .get("repository")
        .and_then(|r| r.get("full_name"))
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    Some((repo_name, branch, commit_sha))
}

/// Extracts pull request details (PR number, action, head commit SHA) from a GitHub `pull_request` payload.
pub fn parse_github_pr_payload(
    payload: &serde_json::Value,
) -> Option<(String, u64, String, String)> {
    let action = payload.get("action")?.as_str()?.to_string();
    let pr_obj = payload.get("pull_request")?;
    let pr_number = pr_obj.get("number")?.as_u64()?;

    let commit_sha = pr_obj
        .get("head")
        .and_then(|h| h.get("sha"))
        .and_then(|v| v.as_str())?
        .to_string();

    let repo_name = payload
        .get("repository")
        .and_then(|r| r.get("full_name"))
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    Some((repo_name, pr_number, action, commit_sha))
}

/// Executes a claimed `Job::Webhook` with total ack/fail semantics.
///
/// Workflow:
/// 1. Verifies the claimed job is `Job::Webhook`.
/// 2. Deduplicates on `delivery_id`; returns early with `ack` if already processed.
/// 3. Validates provider: rejects unverified providers (`gitlab`, `bitbucket`).
/// 4. Dispatches on webhook event:
///    - `ping`: Emits success and acks.
///    - `push`: Evaluates branch deployment policies, enqueues `Job::Build`, emits `git.push` event.
///    - `pull_request`: Triggers preview build on `opened`, `synchronize`, `reopened`.
///    - Other events: Ignored safely with `ack`.
/// 5. Acknowledges the job on success; fails the job on fatal error.
pub async fn run_webhook_job(
    deps: WebhookWorkerDeps<'_>,
    consumer_name: &str,
    queued_job: QueuedJob,
) -> Result<WebhookWorkerOutcome, WebhookError> {
    let WebhookWorkerDeps {
        db,
        queue,
        deduplicator,
        connection,
    } = deps;
    let stream_id = queued_job.stream_id.clone();

    let (delivery_id, provider_str, payload, signature) = match queued_job.job {
        Job::Webhook {
            delivery_id,
            provider,
            payload,
            signature,
        } => (delivery_id, provider, payload, signature),
        other => {
            let reason = format!("Expected Job::Webhook, got {}", other.job_type());
            let _ = queue.fail(&stream_id, &reason).await;
            return Err(WebhookError::InvalidJobVariant(reason));
        }
    };

    // 1. Idempotency & Deduplication check
    if !deduplicator.record_if_new(&delivery_id).await {
        queue.ack(&stream_id).await?;
        return Ok(WebhookWorkerOutcome::DuplicateIgnored { delivery_id });
    }

    // 2. Heartbeat queue claim before payload processing
    queue
        .heartbeat(&stream_id, consumer_name)
        .await
        .map_err(|e| WebhookError::Queue(e.to_string()))?;

    // 3. Provider validation
    let provider = match WebhookProvider::from_str_opt(&provider_str) {
        Some(p) => p,
        None => {
            let reason = format!("Unsupported webhook provider: '{provider_str}'");
            let _ = queue.fail(&stream_id, &reason).await;
            return Err(WebhookError::UnverifiedProvider(reason));
        }
    };

    if provider != WebhookProvider::GitHub {
        let reason = format!(
            "Provider '{provider_str}' signature scheme is unverified per EXTERNAL_APIS.txt §6"
        );
        let _ = queue.fail(&stream_id, &reason).await;
        return Err(WebhookError::UnverifiedProvider(reason));
    }

    // 4. Resolve connection summary and verify signature if secret configured
    if let Some(ref conn) = connection {
        if !signature.is_empty() {
            let raw_json_bytes = serde_json::to_vec(&payload)
                .map_err(|e| WebhookError::Serialization(e.to_string()))?;
            let is_valid = verify_github_signature(
                conn.webhook_secret.as_bytes(),
                &raw_json_bytes,
                &signature,
            )?;
            if !is_valid {
                let reason = "Webhook HMAC-SHA256 signature verification failed".to_string();
                let _ = queue.fail(&stream_id, &reason).await;
                return Err(WebhookError::SignatureMismatch(reason));
            }
        }
    }

    // 5. Inspect event type and handle accordingly
    let event_type = payload
        .get("event")
        .or_else(|| payload.get("x_github_event"))
        .and_then(|v| v.as_str())
        .unwrap_or("push");

    let outcome = match event_type {
        "ping" => WebhookWorkerOutcome::PingAcknowledged,
        "push" => {
            if let Some((repo, branch, commit_sha)) = parse_github_push_payload(&payload) {
                // Emit git.push event per events.md
                let conn_id = connection
                    .as_ref()
                    .map(|c| c.connection_id.clone())
                    .unwrap_or_else(|| "unlinked".to_string());
                let org_id = connection.as_ref().map(|c| c.organization_id.clone());
                let proj_id = connection.as_ref().map(|c| c.project_id.clone());
                let app_id = connection.as_ref().map(|c| c.app_id.clone());

                crate::apps::events::emit(
                    db,
                    "git.push",
                    None,
                    None,
                    None,
                    None,
                    serde_json::json!({
                        "connection_id": conn_id,
                        "repository": repo,
                        "ref": format!("refs/heads/{branch}"),
                        "commit": commit_sha,
                    }),
                )
                .await;

                if let Some(ref conn) = connection {
                    let matching_policy = conn
                        .branch_policies
                        .iter()
                        .find(|p| p.matches_branch(&branch));

                    let target_env = matching_policy
                        .map(|p| p.environment.clone())
                        .unwrap_or_else(|| conn.default_environment_id.clone());

                    let new_build_id = Uuid::new_v4().to_string();
                    let build_job = Job::Build {
                        build_id: new_build_id.clone(),
                        organization_id: org_id.unwrap_or_default(),
                        project_id: proj_id.unwrap_or_default(),
                        app_id: app_id.unwrap_or_default(),
                        environment_id: target_env.clone(),
                        git_commit: commit_sha.clone(),
                        platform: conn.platform.clone(),
                        build_profile: conn.build_profile.clone(),
                    };

                    queue.push(build_job).await?;

                    WebhookWorkerOutcome::BuildTriggered {
                        build_id: new_build_id,
                        commit_sha,
                        branch: Some(branch),
                        environment_id: target_env,
                    }
                } else {
                    WebhookWorkerOutcome::EventIgnored {
                        reason: "No Git connection configured for webhook".to_string(),
                    }
                }
            } else {
                WebhookWorkerOutcome::EventIgnored {
                    reason: "Malformed push payload: missing branch or commit SHA".to_string(),
                }
            }
        }
        "pull_request" => {
            if let Some((repo, pr_num, action, commit_sha)) = parse_github_pr_payload(&payload) {
                let conn_id = connection
                    .as_ref()
                    .map(|c| c.connection_id.clone())
                    .unwrap_or_else(|| "unlinked".to_string());
                let org_id = connection.as_ref().map(|c| c.organization_id.clone());
                let proj_id = connection.as_ref().map(|c| c.project_id.clone());
                let app_id = connection.as_ref().map(|c| c.app_id.clone());

                crate::apps::events::emit(
                    db,
                    "git.pull_request",
                    None,
                    None,
                    None,
                    None,
                    serde_json::json!({
                        "connection_id": conn_id,
                        "repository": repo,
                        "pr_number": pr_num,
                        "action": action,
                    }),
                )
                .await;

                // Handle PR actions that trigger preview builds
                if matches!(action.as_str(), "opened" | "synchronize" | "reopened") {
                    if let Some(ref conn) = connection {
                        let new_build_id = Uuid::new_v4().to_string();
                        let build_job = Job::Build {
                            build_id: new_build_id.clone(),
                            organization_id: org_id.unwrap_or_default(),
                            project_id: proj_id.unwrap_or_default(),
                            app_id: app_id.unwrap_or_default(),
                            environment_id: conn.default_environment_id.clone(),
                            git_commit: commit_sha.clone(),
                            platform: conn.platform.clone(),
                            build_profile: "debug".to_string(),
                        };

                        queue.push(build_job).await?;

                        WebhookWorkerOutcome::BuildTriggered {
                            build_id: new_build_id,
                            commit_sha,
                            branch: None,
                            environment_id: conn.default_environment_id.clone(),
                        }
                    } else {
                        WebhookWorkerOutcome::EventIgnored {
                            reason: "No Git connection configured for webhook".to_string(),
                        }
                    }
                } else {
                    WebhookWorkerOutcome::EventIgnored {
                        reason: format!("Pull request action '{action}' does not trigger builds"),
                    }
                }
            } else {
                WebhookWorkerOutcome::EventIgnored {
                    reason: "Malformed pull_request payload".to_string(),
                }
            }
        }
        other => WebhookWorkerOutcome::EventIgnored {
            reason: format!("Unhandled webhook event: '{other}'"),
        },
    };

    // Total ack contract: acknowledge job from queue
    queue.ack(&stream_id).await?;

    Ok(outcome)
}
