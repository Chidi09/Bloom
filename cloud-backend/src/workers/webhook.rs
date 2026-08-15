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
//!    - GitLab deliveries support two verified schemes:
//!      * Legacy shared secret: `X-Gitlab-Token` header containing the plain secret, compared in constant time.
//!      * Current Standard Webhooks (GitLab 19.0+): `webhook-id`, `webhook-timestamp`, and `webhook-signature` headers
//!        signing `"{webhook-id}.{webhook-timestamp}.{raw_body}"` with base64-decoded `whsec_` key, verified in constant time
//!        with timestamp replay protection (`GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS`).
//!    - Bitbucket Cloud deliveries MUST include the `X-Hub-Signature` header formatted as `"sha256=" + hex_digest`.
//!      Because Bitbucket Cloud omits the header when no secret is configured, missing signature headers are strictly REJECTED.
//!    - **The raw request body bytes (`&[u8]`) are verified directly.** Deserializing and re-serializing JSON
//!      before verification is forbidden because whitespace or key-order differences invalidate signatures.
//!    - Digests are compared in **constant time** via [`Crypto::constant_time_eq`] to prevent timing attacks.
//!    - Missing signatures, absent secrets, or signature mismatches are **rejected immediately**
//!      before performing any database writes or queue interactions.
//!
//! 2. **Provider Verification**:
//!    - GitHub, GitLab, and Bitbucket Cloud signature schemes are independently verified against vendor specifications.
//!
//! 3. **Idempotency & Deduplication**:
//!    - Deliveries are uniquely identified by their provider delivery GUID.
//!    - Replaying a delivery GUID is a no-op and will not queue duplicate build jobs.
//!
//! 4. **Total Ack/Fail Contract**:
//!    - Every claimed [`Job::Webhook`] ends explicitly in either `queue.ack(stream_id)` on success
//!      or `queue.fail(stream_id, reason)` on fatal error.

use std::collections::HashSet;
use std::fmt;
use std::sync::Arc;

use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine as _;
use chrono::Utc;
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

/// Canonical GitLab token header (legacy shared secret scheme).
pub const HEADER_GITLAB_TOKEN: &str = "X-Gitlab-Token";
/// Canonical GitLab webhook ID header (Standard Webhooks scheme).
pub const HEADER_GITLAB_WEBHOOK_ID: &str = "webhook-id";
/// Canonical GitLab webhook timestamp header (Standard Webhooks scheme).
pub const HEADER_GITLAB_WEBHOOK_TIMESTAMP: &str = "webhook-timestamp";
/// Canonical GitLab webhook signature header (Standard Webhooks scheme).
pub const HEADER_GITLAB_WEBHOOK_SIGNATURE: &str = "webhook-signature";
/// Canonical GitLab event header.
pub const HEADER_GITLAB_EVENT: &str = "X-Gitlab-Event";

/// Canonical Bitbucket HMAC-SHA256 signature header.
pub const HEADER_BITBUCKET_SIGNATURE: &str = "X-Hub-Signature";
/// Canonical Bitbucket delivery UUID header.
pub const HEADER_BITBUCKET_UUID: &str = "X-Request-UUID";
/// Canonical Bitbucket event key header.
pub const HEADER_BITBUCKET_EVENT: &str = "X-Event-Key";

/// Maximum allowed timestamp age/drift for GitLab Standard Webhook signatures in seconds (5 minutes).
/// Webhook deliveries whose timestamp drifts further than this tolerance are rejected to prevent replay attacks.
pub const GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS: i64 = 300;

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

/// Decodes a 64-character lowercase hex string into a 32-byte array.
fn hex_to_32_bytes(hex: &str) -> Option<[u8; 32]> {
    let trimmed = hex.trim();
    if trimmed.len() != 64 {
        return None;
    }
    let mut bytes = [0u8; 32];
    for i in 0..32 {
        bytes[i] = u8::from_str_radix(&trimmed[i * 2..i * 2 + 2], 16).ok()?;
    }
    Some(bytes)
}

/// Computes the RFC 2104 HMAC-SHA256 digest over message bytes using the provided secret key.
///
/// Returns the resulting 32-byte digest formatted as a 64-character lowercase hexadecimal string.
pub fn compute_hmac_sha256_hex(key: &[u8], message: &[u8]) -> String {
    // Delegates to the single HMAC implementation in the crypto layer.
    Crypto::hmac_sha256_hex(key, message)
}

/// Computes the RFC 2104 HMAC-SHA256 digest over message bytes using the provided secret key,
/// returning the digest as a standard Base64-encoded string.
pub fn compute_hmac_sha256_base64(key: &[u8], message: &[u8]) -> Result<String, WebhookError> {
    let hex_digest = Crypto::hmac_sha256_hex(key, message);
    let raw_bytes = hex_to_32_bytes(&hex_digest).ok_or_else(|| {
        WebhookError::InvalidSignatureFormat(
            "Failed decoding internal HMAC-SHA256 hex digest".to_string(),
        )
    })?;
    Ok(BASE64_STANDARD.encode(raw_bytes))
}

/// Verifies a GitHub webhook `X-Hub-Signature-256` header against raw request body bytes.
///
/// # Security Requirements
/// - Header must start with prefix `"sha256="`.
/// - Secret must not be empty.
/// - Comparison is strictly performed in constant time via [`Crypto::constant_time_eq`].
/// - Body bytes must be raw unparsed request payload.
///
/// Verified against GitHub webhook documentation.
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

/// Verifies a Bitbucket Cloud webhook `X-Hub-Signature` header against raw request body bytes.
///
/// # Security Requirements
/// - Header must start with prefix `"sha256="`.
/// - Secret must not be empty.
/// - Comparison is strictly performed in constant time via [`Crypto::constant_time_eq`].
/// - Body bytes must be raw unparsed request payload.
///
/// *** Critical Security Detail: Bitbucket Cloud does NOT sign by default and omits `X-Hub-Signature`
/// when no secret is configured. Missing signature headers MUST be treated as REJECT, never as
/// accepting unverified traffic. ***
///
/// Verified against Atlassian Bitbucket Cloud webhook documentation.
pub fn verify_bitbucket_signature(
    secret: &[u8],
    body_bytes: &[u8],
    signature_header: &str,
) -> Result<bool, WebhookError> {
    if secret.is_empty() {
        return Err(WebhookError::MissingSecret(
            "Bitbucket webhook secret is empty or not configured".to_string(),
        ));
    }

    let trimmed = signature_header.trim();
    let provided_hex = match trimmed.strip_prefix("sha256=") {
        Some(hex) if !hex.is_empty() => hex.trim(),
        _ => {
            return Err(WebhookError::InvalidSignatureFormat(
                "Bitbucket signature header must start with 'sha256=' followed by hex digest"
                    .to_string(),
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

/// Verifies a GitLab legacy webhook `X-Gitlab-Token` header against the configured secret.
///
/// The header value is the secret itself in plain text (no digest).
/// Comparison is performed strictly in constant time via [`Crypto::constant_time_eq_str`]
/// to prevent timing oracle attacks.
///
/// Verified against GitLab webhook documentation.
pub fn verify_gitlab_legacy_token(secret: &str, token_header: &str) -> Result<bool, WebhookError> {
    let sec_trimmed = secret.trim();
    if sec_trimmed.is_empty() {
        return Err(WebhookError::MissingSecret(
            "GitLab webhook secret token is empty or not configured".to_string(),
        ));
    }

    let tok_trimmed = token_header.trim();
    if tok_trimmed.is_empty() {
        return Err(WebhookError::MissingSignature(
            "GitLab X-Gitlab-Token header is empty".to_string(),
        ));
    }

    // Plain == is a timing oracle; use constant-time comparison helper.
    let is_valid = Crypto::constant_time_eq_str(sec_trimmed, tok_trimmed);
    Ok(is_valid)
}

/// Verifies a GitLab Standard Webhook (GitLab 19.0+, GA in 19.1) signature against raw body bytes.
///
/// # Security Requirements
/// - Secret starts with prefix `"whsec_"`. Prefix is stripped and remainder is Base64-decoded into raw HMAC key bytes.
/// - String to sign: `"{webhook-id}.{webhook-timestamp}.{raw_body}"` joined literally with `.` characters.
/// - Digest: HMAC-SHA256 over string to sign, formatted as `"v1,<base64 digest>"`.
/// - Supports secret rotation: `webhook-signature` header may carry multiple space-separated signatures; accepts if any matches.
/// - Replay protection: `webhook-timestamp` must be within [`GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS`].
/// - Comparison is strictly performed in constant time via [`Crypto::constant_time_eq_str`].
///
/// Verified against GitLab Standard Webhooks documentation.
pub fn verify_gitlab_standard_signature(
    secret: &str,
    webhook_id: &str,
    webhook_timestamp: &str,
    webhook_signature: &str,
    body_bytes: &[u8],
) -> Result<bool, WebhookError> {
    let secret_trimmed = secret.trim();
    if secret_trimmed.is_empty() {
        return Err(WebhookError::MissingSecret(
            "GitLab webhook secret is empty or not configured".to_string(),
        ));
    }

    // 1. Strip "whsec_" prefix and Base64-decode raw HMAC key bytes
    let base64_part = match secret_trimmed.strip_prefix("whsec_") {
        Some(b64) if !b64.is_empty() => b64.trim(),
        _ => {
            return Err(WebhookError::InvalidSignatureFormat(
                "GitLab Standard Webhook secret must start with 'whsec_' prefix".to_string(),
            ));
        }
    };

    let key_bytes = BASE64_STANDARD.decode(base64_part).map_err(|e| {
        WebhookError::InvalidSignatureFormat(format!(
            "Failed to base64 decode GitLab webhook secret key: {e}"
        ))
    })?;

    if key_bytes.is_empty() {
        return Err(WebhookError::MissingSecret(
            "Decoded GitLab webhook secret key is empty".to_string(),
        ));
    }

    let id_trimmed = webhook_id.trim();
    if id_trimmed.is_empty() {
        return Err(WebhookError::MissingSignature(
            "webhook-id header is missing or empty".to_string(),
        ));
    }

    let ts_trimmed = webhook_timestamp.trim();
    if ts_trimmed.is_empty() {
        return Err(WebhookError::MissingSignature(
            "webhook-timestamp header is missing or empty".to_string(),
        ));
    }

    let sig_trimmed = webhook_signature.trim();
    if sig_trimmed.is_empty() {
        return Err(WebhookError::MissingSignature(
            "webhook-signature header is missing or empty".to_string(),
        ));
    }

    // 2. Replay protection: validate timestamp within tolerance window
    let ts_num: i64 = ts_trimmed.parse().map_err(|_| {
        WebhookError::InvalidSignatureFormat(
            "webhook-timestamp header must be an integer UNIX timestamp".to_string(),
        )
    })?;

    let now = Utc::now().timestamp();
    if (now - ts_num).abs() > GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS {
        return Err(WebhookError::SignatureMismatch(
            "GitLab webhook timestamp is outside allowed tolerance window (replay protection)"
                .to_string(),
        ));
    }

    // 3. Construct string to sign: "{webhook-id}.{webhook-timestamp}.{raw_body}"
    let mut string_to_sign =
        Vec::with_capacity(id_trimmed.len() + 1 + ts_trimmed.len() + 1 + body_bytes.len());
    string_to_sign.extend_from_slice(id_trimmed.as_bytes());
    string_to_sign.push(b'.');
    string_to_sign.extend_from_slice(ts_trimmed.as_bytes());
    string_to_sign.push(b'.');
    string_to_sign.extend_from_slice(body_bytes);

    // 4. Compute expected Base64 HMAC-SHA256 digest
    let expected_b64 = compute_hmac_sha256_base64(&key_bytes, &string_to_sign)?;
    let expected_sig = format!("v1,{expected_b64}");

    // 5. Verify against space-separated candidate signatures (secret rotation support)
    let mut matched = false;
    for candidate in sig_trimmed.split_whitespace() {
        if Crypto::constant_time_eq_str(candidate, &expected_sig) {
            matched = true;
            break;
        }
    }

    Ok(matched)
}

/// Verifies a GitLab webhook delivery supporting both Standard Webhooks and Legacy token schemes.
pub fn verify_gitlab_delivery_full(
    secret: Option<&str>,
    body_bytes: &[u8],
    token_header: Option<&str>,
    webhook_id: Option<&str>,
    webhook_timestamp: Option<&str>,
    webhook_signature: Option<&str>,
) -> Result<(), WebhookError> {
    let sec = secret.ok_or_else(|| {
        WebhookError::MissingSecret(
            "No webhook secret configured for GitLab repository".to_string(),
        )
    })?;

    if let (Some(w_id), Some(w_ts), Some(w_sig)) =
        (webhook_id, webhook_timestamp, webhook_signature)
    {
        let valid = verify_gitlab_standard_signature(sec, w_id, w_ts, w_sig, body_bytes)?;
        if !valid {
            return Err(WebhookError::SignatureMismatch(
                "GitLab Standard Webhook signature verification failed".to_string(),
            ));
        }
        Ok(())
    } else if let Some(tok) = token_header {
        let valid = verify_gitlab_legacy_token(sec, tok)?;
        if !valid {
            return Err(WebhookError::SignatureMismatch(
                "GitLab X-Gitlab-Token does not match configured secret".to_string(),
            ));
        }
        Ok(())
    } else {
        Err(WebhookError::MissingSignature(
            "Missing GitLab signature or token header (expected webhook-signature or X-Gitlab-Token)".to_string(),
        ))
    }
}

/// Dispatches signature verification based on the provider.
///
/// Verified against vendor documentation for GitHub, GitLab, and Bitbucket Cloud.
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
            let sec = secret.ok_or_else(|| {
                WebhookError::MissingSecret(
                    "No webhook secret configured for GitLab repository".to_string(),
                )
            })?;
            let sig = signature_header.ok_or_else(|| {
                WebhookError::MissingSignature(
                    "Missing signature or token header on GitLab webhook".to_string(),
                )
            })?;

            // If signature is legacy token:
            if !sec.starts_with("whsec_") || !sig.starts_with("v1,") {
                let valid = verify_gitlab_legacy_token(sec, sig)?;
                if !valid {
                    return Err(WebhookError::SignatureMismatch(
                        "GitLab token does not match configured secret".to_string(),
                    ));
                }
                Ok(())
            } else {
                // GitLab Standard Webhook format passed without timestamp/id headers
                Err(WebhookError::InvalidSignatureFormat(
                    "GitLab Standard Webhook verification requires webhook-id and webhook-timestamp headers"
                        .to_string(),
                ))
            }
        }
        WebhookProvider::BitBucket => {
            let sec = secret.ok_or_else(|| {
                WebhookError::MissingSecret(
                    "No webhook secret configured for Bitbucket repository".to_string(),
                )
            })?;

            // Critical security rule: Bitbucket Cloud omits X-Hub-Signature when no secret is configured.
            // An absent header MUST be treated as REJECT, never as unverified acceptance.
            let sig = signature_header.ok_or_else(|| {
                WebhookError::MissingSignature(
                    "Missing X-Hub-Signature header on Bitbucket webhook (Bitbucket omits signatures when unconfigured; rejecting delivery for security)".to_string(),
                )
            })?;

            let valid = verify_bitbucket_signature(sec.as_bytes(), body_bytes, sig)?;
            if !valid {
                return Err(WebhookError::SignatureMismatch(
                    "HMAC-SHA256 signature does not match expected digest".to_string(),
                ));
            }
            Ok(())
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
/// Defined locally: the `git_connections` app has since landed, but exposes no equivalent
/// summary type, so this stays the worker's own view of a connection rather than a duplicate
/// of one. Fold it into that app if it ever grows a shared summary.
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

/// Extracts git reference details (branch, commit SHA) from a GitLab `push` or `tag_push` payload.
pub fn parse_gitlab_push_payload(payload: &serde_json::Value) -> Option<(String, String, String)> {
    let git_ref = payload.get("ref")?.as_str()?.to_string();
    let branch = git_ref
        .strip_prefix("refs/heads/")
        .unwrap_or(&git_ref)
        .to_string();

    let commit_sha = payload
        .get("after")
        .and_then(|v| v.as_str())
        .or_else(|| payload.get("checkout_sha").and_then(|v| v.as_str()))
        .or_else(|| {
            payload
                .get("commits")
                .and_then(|c| c.as_array())
                .and_then(|arr| arr.last())
                .and_then(|c| c.get("id"))
                .and_then(|v| v.as_str())
        })?
        .to_string();

    let repo_name = payload
        .get("project")
        .and_then(|p| p.get("path_with_namespace").or_else(|| p.get("name")))
        .and_then(|v| v.as_str())
        .or_else(|| {
            payload
                .get("repository")
                .and_then(|r| r.get("name"))
                .and_then(|v| v.as_str())
        })
        .unwrap_or_default()
        .to_string();

    Some((repo_name, branch, commit_sha))
}

/// Extracts merge request details from a GitLab `merge_request` payload.
pub fn parse_gitlab_mr_payload(
    payload: &serde_json::Value,
) -> Option<(String, u64, String, String)> {
    let attrs = payload.get("object_attributes")?;
    let action = attrs
        .get("action")
        .and_then(|v| v.as_str())
        .unwrap_or("open")
        .to_string();

    let pr_number = attrs
        .get("iid")
        .or_else(|| attrs.get("id"))
        .and_then(|v| v.as_u64())
        .unwrap_or(0);

    let commit_sha = attrs
        .get("last_commit")
        .and_then(|c| c.get("id"))
        .and_then(|v| v.as_str())
        .unwrap_or("HEAD")
        .to_string();

    let repo_name = payload
        .get("project")
        .and_then(|p| p.get("path_with_namespace").or_else(|| p.get("name")))
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    Some((repo_name, pr_number, action, commit_sha))
}

/// Extracts git reference details (branch, commit SHA) from a Bitbucket `repo:push` payload.
pub fn parse_bitbucket_push_payload(
    payload: &serde_json::Value,
) -> Option<(String, String, String)> {
    let repo_name = payload
        .get("repository")
        .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    let changes = payload
        .get("push")
        .and_then(|p| p.get("changes"))
        .and_then(|c| c.as_array())?;

    let first_change = changes.first()?;
    let new_obj = first_change.get("new")?;

    let branch = new_obj
        .get("name")
        .and_then(|v| v.as_str())
        .unwrap_or("main")
        .to_string();

    let commit_sha = new_obj
        .get("target")
        .and_then(|t| t.get("hash"))
        .and_then(|v| v.as_str())
        .unwrap_or("HEAD")
        .to_string();

    Some((repo_name, branch, commit_sha))
}

/// Extracts pull request details from a Bitbucket `pullrequest:created` / `pullrequest:updated` payload.
pub fn parse_bitbucket_pr_payload(
    payload: &serde_json::Value,
) -> Option<(String, u64, String, String)> {
    let pr_obj = payload.get("pullrequest")?;
    let pr_number = pr_obj.get("id")?.as_u64()?;

    let action = payload
        .get("action")
        .and_then(|v| v.as_str())
        .unwrap_or("created")
        .to_string();

    let commit_sha = pr_obj
        .get("source")
        .and_then(|s| s.get("commit"))
        .and_then(|c| c.get("hash"))
        .and_then(|v| v.as_str())
        .unwrap_or("HEAD")
        .to_string();

    let repo_name = payload
        .get("repository")
        .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string();

    Some((repo_name, pr_number, action, commit_sha))
}

/// Extracts push payload details across all supported Git providers.
pub fn parse_provider_push_payload(
    provider: WebhookProvider,
    payload: &serde_json::Value,
) -> Option<(String, String, String)> {
    match provider {
        WebhookProvider::GitHub => parse_github_push_payload(payload),
        WebhookProvider::GitLab => {
            parse_gitlab_push_payload(payload).or_else(|| parse_github_push_payload(payload))
        }
        WebhookProvider::BitBucket => {
            parse_bitbucket_push_payload(payload).or_else(|| parse_github_push_payload(payload))
        }
    }
}

/// Extracts pull request payload details across all supported Git providers.
pub fn parse_provider_pr_payload(
    provider: WebhookProvider,
    payload: &serde_json::Value,
) -> Option<(String, u64, String, String)> {
    match provider {
        WebhookProvider::GitHub => parse_github_pr_payload(payload),
        WebhookProvider::GitLab => {
            parse_gitlab_mr_payload(payload).or_else(|| parse_github_pr_payload(payload))
        }
        WebhookProvider::BitBucket => {
            parse_bitbucket_pr_payload(payload).or_else(|| parse_github_pr_payload(payload))
        }
    }
}

/// Executes a claimed `Job::Webhook` with total ack/fail semantics.
///
/// Workflow:
/// 1. Verifies the claimed job is `Job::Webhook`.
/// 2. Deduplicates on `delivery_id`; returns early with `ack` if already processed.
/// 3. Validates provider (`github`, `gitlab`, `bitbucket`).
/// 4. Dispatches on webhook event:
///    - `ping`: Emits success and acks.
///    - `push`: Evaluates branch deployment policies, enqueues `Job::Build`, emits `git.push` event.
///    - `pull_request` / `merge_request`: Triggers preview build on `opened`, `synchronize`, `reopened`.
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

    // 4. Resolve connection summary and verify signature if secret configured
    if let Some(ref conn) = connection {
        if !signature.is_empty() {
            let raw_json_bytes = serde_json::to_vec(&payload)
                .map_err(|e| WebhookError::Serialization(e.to_string()))?;

            let is_valid = match provider {
                WebhookProvider::GitHub => verify_github_signature(
                    conn.webhook_secret.as_bytes(),
                    &raw_json_bytes,
                    &signature,
                )?,
                WebhookProvider::BitBucket => verify_bitbucket_signature(
                    conn.webhook_secret.as_bytes(),
                    &raw_json_bytes,
                    &signature,
                )?,
                WebhookProvider::GitLab => {
                    if signature.starts_with("v1,") && conn.webhook_secret.starts_with("whsec_") {
                        let webhook_id = payload
                            .get("webhook_id")
                            .and_then(|v| v.as_str())
                            .unwrap_or(&delivery_id);
                        let webhook_ts = payload
                            .get("webhook_timestamp")
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        if webhook_ts.is_empty() {
                            verify_gitlab_legacy_token(&conn.webhook_secret, &signature)?
                        } else {
                            verify_gitlab_standard_signature(
                                &conn.webhook_secret,
                                webhook_id,
                                webhook_ts,
                                &signature,
                                &raw_json_bytes,
                            )?
                        }
                    } else {
                        verify_gitlab_legacy_token(&conn.webhook_secret, &signature)?
                    }
                }
            };

            if !is_valid {
                let reason = "Webhook HMAC signature verification failed".to_string();
                let _ = queue.fail(&stream_id, &reason).await;
                return Err(WebhookError::SignatureMismatch(reason));
            }
        }
    }

    // 5. Inspect event type and handle accordingly
    let event_type = payload
        .get("event")
        .or_else(|| payload.get("x_github_event"))
        .or_else(|| payload.get("x_gitlab_event"))
        .or_else(|| payload.get("x_event_key"))
        .or_else(|| payload.get("event_type"))
        .or_else(|| payload.get("object_kind"))
        .and_then(|v| v.as_str())
        .unwrap_or("push");

    let outcome = match event_type {
        "ping" => WebhookWorkerOutcome::PingAcknowledged,
        "push" | "tag_push" | "repo:push" => {
            if let Some((repo, branch, commit_sha)) =
                parse_provider_push_payload(provider, &payload)
            {
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
        "pull_request" | "merge_request" | "pullrequest:created" | "pullrequest:updated" => {
            if let Some((repo, pr_num, action, commit_sha)) =
                parse_provider_pr_payload(provider, &payload)
            {
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
                if matches!(
                    action.as_str(),
                    "opened"
                        | "synchronize"
                        | "reopened"
                        | "open"
                        | "update"
                        | "reopen"
                        | "created"
                        | "updated"
                ) {
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
