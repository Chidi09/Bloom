//! Business logic, HMAC signature verification, idempotency deduplication, and operations for `git_connections`.

use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine as _;
use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{GitConnectionCreateRequest, RepositoryResponse};
use super::errors::GitConnectionError;
use super::models::{GitConnection, WebhookDelivery};
use super::repositories;
use crate::infra::crypto::Crypto;

/// Allowed Git provider identifiers.
pub const ALLOWED_PROVIDERS: &[&str] = &["github", "gitlab", "bitbucket"];

/// Maximum allowed timestamp age/drift for GitLab Standard Webhook signatures in seconds (5 minutes).
/// Webhook deliveries whose timestamp drifts further than this tolerance are rejected to prevent replay attacks.
pub const GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS: i64 = 300;

/// Outcome of processing an inbound webhook delivery.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WebhookDeliveryOutcome {
    /// Delivery was successfully processed and domain event was emitted.
    Processed {
        /// Type of event handled (e.g. `push`, `pull_request`, `ping`).
        event_type: String,
        /// Message describing the processing outcome.
        message: String,
    },
    /// Delivery was previously received and was skipped for idempotency.
    AlreadyProcessed {
        /// Unique delivery GUID that was deduped.
        delivery_id: String,
    },
    /// Delivery was received but ignored because the event type is not subscribed.
    Ignored {
        /// Type of unhandled event.
        event_type: String,
    },
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

/// Headers and parameters for verifying and handling GitLab webhook deliveries.
#[derive(Debug, Clone, Default)]
pub struct GitLabWebhookHeaders<'a> {
    /// Value of `X-Gitlab-Token` header (Legacy plain secret scheme).
    pub token: Option<&'a str>,
    /// Value of `webhook-id` header (Standard Webhooks scheme).
    pub webhook_id: Option<&'a str>,
    /// Value of `webhook-timestamp` header (Standard Webhooks scheme).
    pub webhook_timestamp: Option<&'a str>,
    /// Value of `webhook-signature` header (Standard Webhooks scheme).
    pub webhook_signature: Option<&'a str>,
    /// Value of `X-Gitlab-Event` header.
    pub event_type: Option<&'a str>,
    /// Delivery ID or unique request GUID.
    pub delivery_id: Option<&'a str>,
}

/// Helper to decode a 64-character lowercase hex string into a 32-byte array.
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

/// Computes HMAC-SHA256 hex digest over raw message bytes with the given secret.
///
/// Implements RFC 2104 / FIPS 198 HMAC-SHA256 without third-party wrapper dependencies.
pub fn compute_hmac_sha256(secret: &[u8], message: &[u8]) -> String {
    // Delegates to the single HMAC implementation in the crypto layer.
    Crypto::hmac_sha256_hex(secret, message)
}

/// Computes HMAC-SHA256 over message bytes using the provided secret key, returning the Base64 digest string.
pub fn compute_hmac_sha256_base64(
    secret: &[u8],
    message: &[u8],
) -> Result<String, GitConnectionError> {
    let hex_digest = Crypto::hmac_sha256_hex(secret, message);
    let raw_bytes =
        hex_to_32_bytes(&hex_digest).ok_or(GitConnectionError::InvalidSignatureFormat)?;
    Ok(BASE64_STANDARD.encode(raw_bytes))
}

/// Verify GitHub webhook signature against raw request body bytes.
///
/// Security Boundary Requirements:
/// - Header must be `X-Hub-Signature-256`, value format: `sha256=<hex_digest>`.
/// - Must take raw `&[u8]` body bytes, NOT re-serialized JSON.
/// - Compares digests using constant-time comparison via [`Crypto::constant_time_eq`].
/// - Rejects immediately on missing secret, missing signature, or digest mismatch.
pub fn verify_github_signature(
    secret: &str,
    signature_header: Option<&str>,
    body: &[u8],
) -> Result<(), GitConnectionError> {
    if secret.trim().is_empty() {
        return Err(GitConnectionError::MissingSecret);
    }

    let raw_sig = match signature_header {
        Some(s) if !s.trim().is_empty() => s.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    let hex_sig = match raw_sig.strip_prefix("sha256=") {
        Some(h) if !h.is_empty() => h,
        _ => return Err(GitConnectionError::InvalidSignatureFormat),
    };

    let expected_hex = compute_hmac_sha256(secret.as_bytes(), body);

    if Crypto::constant_time_eq(hex_sig.as_bytes(), expected_hex.as_bytes()) {
        Ok(())
    } else {
        Err(GitConnectionError::InvalidSignature)
    }
}

/// Verify Bitbucket Cloud webhook signature against raw request body bytes.
///
/// Security Boundary Requirements:
/// - Header must be `X-Hub-Signature`, value format: `sha256=<hex_digest>`.
/// - Must take raw `&[u8]` body bytes, NOT re-serialized JSON.
/// - Compares digests using constant-time comparison via [`Crypto::constant_time_eq`].
/// - Rejects immediately on missing secret, missing signature, or digest mismatch.
///
/// *** Critical Security Detail: Bitbucket Cloud does NOT sign by default. The secret is optional,
/// and when no secret is configured Bitbucket OMITS the `X-Hub-Signature` header entirely.
/// Therefore, a MISSING signature header MUST be treated as REJECT, never as accepting unverified deliveries. ***
pub fn verify_bitbucket_signature(
    secret: &str,
    signature_header: Option<&str>,
    body: &[u8],
) -> Result<(), GitConnectionError> {
    if secret.trim().is_empty() {
        return Err(GitConnectionError::MissingSecret);
    }

    // Critical security check: Bitbucket Cloud omits the header when no secret is configured.
    // An absent signature header is strictly REJECTED to prevent unauthenticated push forgery.
    let raw_sig = match signature_header {
        Some(s) if !s.trim().is_empty() => s.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    let hex_sig = match raw_sig.strip_prefix("sha256=") {
        Some(h) if !h.is_empty() => h,
        _ => return Err(GitConnectionError::InvalidSignatureFormat),
    };

    let expected_hex = compute_hmac_sha256(secret.as_bytes(), body);

    if Crypto::constant_time_eq(hex_sig.as_bytes(), expected_hex.as_bytes()) {
        Ok(())
    } else {
        Err(GitConnectionError::InvalidSignature)
    }
}

/// Verify GitLab legacy webhook `X-Gitlab-Token` header.
///
/// The header value is the secret itself in plain text (no digest).
/// Comparison is performed strictly in constant time via [`Crypto::constant_time_eq_str`]
/// to prevent timing oracle attacks.
pub fn verify_gitlab_legacy_token(
    secret: &str,
    token_header: Option<&str>,
) -> Result<(), GitConnectionError> {
    let sec_trimmed = secret.trim();
    if sec_trimmed.is_empty() {
        return Err(GitConnectionError::MissingSecret);
    }

    let raw_tok = match token_header {
        Some(t) if !t.trim().is_empty() => t.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    if Crypto::constant_time_eq_str(sec_trimmed, raw_tok) {
        Ok(())
    } else {
        Err(GitConnectionError::InvalidSignature)
    }
}

/// Verify GitLab Standard Webhook (GitLab 19.0+, GA in 19.1) signature.
///
/// # Security Requirements
/// - Secret starts with prefix `"whsec_"`. Prefix is stripped and remainder is Base64-decoded into raw HMAC key bytes.
/// - String to sign: `"{webhook-id}.{webhook-timestamp}.{raw_body}"` joined literally with `.` characters.
/// - Digest: HMAC-SHA256 over string to sign, formatted as `"v1,<base64 digest>"`.
/// - Supports secret rotation: `webhook-signature` header may carry multiple space-separated signatures; accepts if any matches.
/// - Replay protection: `webhook-timestamp` must be within [`GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS`].
/// - Comparison is strictly performed in constant time via [`Crypto::constant_time_eq_str`].
pub fn verify_gitlab_standard_signature(
    secret: &str,
    webhook_id: Option<&str>,
    webhook_timestamp: Option<&str>,
    webhook_signature: Option<&str>,
    body: &[u8],
) -> Result<(), GitConnectionError> {
    let secret_trimmed = secret.trim();
    if secret_trimmed.is_empty() {
        return Err(GitConnectionError::MissingSecret);
    }

    let base64_part = match secret_trimmed.strip_prefix("whsec_") {
        Some(b64) if !b64.is_empty() => b64.trim(),
        _ => return Err(GitConnectionError::InvalidSignatureFormat),
    };

    let key_bytes = BASE64_STANDARD
        .decode(base64_part)
        .map_err(|_| GitConnectionError::InvalidSignatureFormat)?;

    if key_bytes.is_empty() {
        return Err(GitConnectionError::MissingSecret);
    }

    let w_id = match webhook_id {
        Some(id) if !id.trim().is_empty() => id.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    let w_ts = match webhook_timestamp {
        Some(ts) if !ts.trim().is_empty() => ts.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    let w_sig = match webhook_signature {
        Some(sig) if !sig.trim().is_empty() => sig.trim(),
        _ => return Err(GitConnectionError::MissingSignature),
    };

    // Replay protection
    let ts_num: i64 = w_ts
        .parse()
        .map_err(|_| GitConnectionError::InvalidSignatureFormat)?;
    let now = Utc::now().timestamp();
    if (now - ts_num).abs() > GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS {
        return Err(GitConnectionError::InvalidSignature);
    }

    // String to sign
    let mut string_to_sign = Vec::with_capacity(w_id.len() + 1 + w_ts.len() + 1 + body.len());
    string_to_sign.extend_from_slice(w_id.as_bytes());
    string_to_sign.push(b'.');
    string_to_sign.extend_from_slice(w_ts.as_bytes());
    string_to_sign.push(b'.');
    string_to_sign.extend_from_slice(body);

    let expected_b64 = compute_hmac_sha256_base64(&key_bytes, &string_to_sign)?;
    let expected_sig = format!("v1,{expected_b64}");

    for candidate in w_sig.split_whitespace() {
        if Crypto::constant_time_eq_str(candidate, &expected_sig) {
            return Ok(());
        }
    }

    Err(GitConnectionError::InvalidSignature)
}

/// Verify GitLab webhook delivery supporting both Standard Webhooks and Legacy token schemes.
pub fn verify_gitlab_webhook(
    secret: &str,
    headers: &GitLabWebhookHeaders<'_>,
    body: &[u8],
) -> Result<(), GitConnectionError> {
    if headers.webhook_signature.is_some()
        || (headers.webhook_id.is_some() && headers.webhook_timestamp.is_some())
    {
        verify_gitlab_standard_signature(
            secret,
            headers.webhook_id,
            headers.webhook_timestamp,
            headers.webhook_signature,
            body,
        )
    } else if headers.token.is_some() {
        verify_gitlab_legacy_token(secret, headers.token)
    } else {
        Err(GitConnectionError::MissingSignature)
    }
}

/// Create a new encrypted Git connection for an organization.
pub async fn create_connection(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: GitConnectionCreateRequest,
) -> Result<GitConnection, GitConnectionError> {
    let provider = req.provider.trim().to_ascii_lowercase();
    if !ALLOWED_PROVIDERS.contains(&provider.as_str()) {
        return Err(GitConnectionError::InvalidProvider(provider));
    }

    let installation_id = req.installation_id.trim();
    if installation_id.is_empty() {
        return Err(GitConnectionError::InvalidInstallationId(
            "Installation ID cannot be empty".to_string(),
        ));
    }

    let access_token = req.access_token.trim();
    if access_token.is_empty() {
        return Err(GitConnectionError::InvalidToken(
            "Access token cannot be empty".to_string(),
        ));
    }

    if repositories::connection_exists_in_org(db, organization_id, &provider, installation_id)
        .await?
    {
        return Err(GitConnectionError::ConnectionAlreadyExists);
    }

    let metadata_str = match req.metadata {
        Some(val) => serde_json::to_string(&val).unwrap_or_else(|_| "{}".to_string()),
        None => "{}".to_string(),
    };

    let encrypted_access_token = Crypto::encrypt(access_token)?;

    let now = Utc::now();
    let connection = GitConnection {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        provider: provider.clone(),
        installation_id: installation_id.to_string(),
        encrypted_access_token,
        metadata: metadata_str,
        created_at: now,
        updated_at: now,
    };

    let saved = repositories::insert_connection(db, connection).await?;

    // Emit git.connected event per docs/events.md
    emit_event(
        db,
        "git.connected",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        serde_json::json!({
            "connection_id": saved.public_id,
            "provider": saved.provider,
        }),
    )
    .await;

    Ok(saved)
}

/// List all Git connections belonging to an organization with pagination.
pub async fn list_connections(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<GitConnection>, i64), GitConnectionError> {
    let (connections, total) =
        repositories::list_connections_query(db, organization_id, limit, offset).await?;
    Ok((connections, total))
}

/// Retrieve a single Git connection by public UUID within an organization.
pub async fn get_connection(
    db: &Database,
    organization_id: i64,
    public_id: &str,
) -> Result<GitConnection, GitConnectionError> {
    repositories::connection_by_public_id_and_org(db, public_id, organization_id)
        .await?
        .ok_or(GitConnectionError::ConnectionNotFound)
}

/// Delete a Git connection and emit `git.disconnected`.
pub async fn delete_connection(
    db: &Database,
    connection: &GitConnection,
    user_id: i64,
) -> Result<(), GitConnectionError> {
    repositories::delete_connection_by_id(db, connection.id).await?;

    // Emit git.disconnected event per docs/events.md
    emit_event(
        db,
        "git.disconnected",
        Some(connection.organization_id.id),
        None,
        None,
        Some(user_id),
        serde_json::json!({
            "connection_id": connection.public_id,
            "provider": connection.provider,
        }),
    )
    .await;

    Ok(())
}

/// List repositories available for a connection from metadata or decrypted credentials.
pub async fn list_repositories(
    _db: &Database,
    connection: &GitConnection,
) -> Result<Vec<RepositoryResponse>, GitConnectionError> {
    // Verify ciphertext can be decrypted
    let _decrypted_token = Crypto::decrypt(&connection.encrypted_access_token)?;

    // Parse repository list from stored metadata if present
    if let Ok(metadata_val) = serde_json::from_str::<serde_json::Value>(&connection.metadata) {
        if let Some(repos_array) = metadata_val.get("repositories").and_then(|r| r.as_array()) {
            let mut result = Vec::new();
            for repo in repos_array {
                let id = repo
                    .get("id")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                let full_name = repo
                    .get("full_name")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                let default_branch = repo
                    .get("default_branch")
                    .and_then(|v| v.as_str())
                    .unwrap_or("main")
                    .to_string();
                let url = repo
                    .get("url")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();

                if !full_name.is_empty() {
                    result.push(RepositoryResponse {
                        id: if id.is_empty() { full_name.clone() } else { id },
                        full_name,
                        default_branch,
                        url,
                    });
                }
            }
            if !result.is_empty() {
                return Ok(result);
            }
        }
    }

    // Default repository response derived from installation metadata
    Ok(Vec::new())
}

/// Handles an incoming GitHub webhook delivery.
///
/// Steps:
/// 1. Verify `X-Hub-Signature-256` HMAC-SHA256 against raw body bytes.
/// 2. Deduplicate on `X-GitHub-Delivery` GUID using database unique constraint.
/// 3. If duplicate, return [`WebhookDeliveryOutcome::AlreadyProcessed`] (idempotent no-op).
/// 4. Dispatch event (`ping`, `push`, `pull_request`) and emit appropriate domain event per `docs/events.md`.
pub async fn handle_github_webhook(
    db: &Database,
    webhook_secret: Option<&str>,
    signature_header: Option<&str>,
    delivery_id_header: Option<&str>,
    event_type_header: Option<&str>,
    raw_body: &[u8],
) -> Result<WebhookDeliveryOutcome, GitConnectionError> {
    // 1. Webhook signature verification (Security Boundary)
    let secret = webhook_secret.ok_or(GitConnectionError::MissingSecret)?;
    verify_github_signature(secret, signature_header, raw_body)?;

    // 2. Validate delivery GUID header
    let delivery_guid = match delivery_id_header {
        Some(d) if !d.trim().is_empty() => d.trim(),
        _ => return Err(GitConnectionError::MissingDeliveryId),
    };

    let event_type = event_type_header.unwrap_or("push").trim();

    // 3. Deduplicate delivery ID (Phase 6 Exit Gate: Idempotency)
    if repositories::delivery_exists(db, delivery_guid).await? {
        return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
            delivery_id: delivery_guid.to_string(),
        });
    }

    let payload_str = String::from_utf8_lossy(raw_body).to_string();
    let delivery = WebhookDelivery {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        provider: "github".to_string(),
        delivery_id: delivery_guid.to_string(),
        event_type: event_type.to_string(),
        payload: payload_str,
        status: "received".to_string(),
        created_at: Utc::now(),
    };

    let saved_delivery = match repositories::insert_delivery(db, delivery).await {
        Ok(d) => d,
        Err(_) => {
            // Concurrent race on insert -> treat as already processed
            return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
                delivery_id: delivery_guid.to_string(),
            });
        }
    };

    // 4. Parse payload JSON
    let parsed_json: serde_json::Value = serde_json::from_slice(raw_body)
        .map_err(|e| GitConnectionError::InvalidPayload(e.to_string()))?;

    // Look up optional connection by installation ID if present in payload
    let installation_id_opt = parsed_json
        .get("installation")
        .and_then(|i| i.get("id"))
        .and_then(|id| {
            if id.is_number() {
                Some(id.to_string())
            } else {
                id.as_str().map(|s| s.to_string())
            }
        });

    let connection_opt = if let Some(ref inst_id) = installation_id_opt {
        repositories::connection_by_provider_and_installation(db, "github", inst_id).await?
    } else {
        None
    };

    let connection_public_id = connection_opt
        .as_ref()
        .map(|c| c.public_id.clone())
        .unwrap_or_else(|| "github".to_string());

    let org_id_opt = connection_opt.as_ref().map(|c| c.organization_id.id);

    // 5. Handle event types per docs/integrations/github.md and docs/events.md
    match event_type {
        "ping" => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;
            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "ping".to_string(),
                message: "GitHub ping acknowledged successfully".to_string(),
            })
        }
        "push" => {
            let repository = parsed_json
                .get("repository")
                .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let git_ref = parsed_json
                .get("ref")
                .and_then(|r| r.as_str())
                .unwrap_or("refs/heads/main")
                .to_string();

            let commit_sha = parsed_json
                .get("after")
                .or_else(|| parsed_json.get("head_commit").and_then(|c| c.get("id")))
                .and_then(|c| c.as_str())
                .unwrap_or("HEAD")
                .to_string();

            // Emit git.push event per docs/events.md
            emit_event(
                db,
                "git.push",
                org_id_opt,
                None,
                None,
                None, // System actor
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "ref": git_ref,
                    "commit": commit_sha,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "push".to_string(),
                message: "Push webhook processed and git.push event emitted".to_string(),
            })
        }
        "pull_request" => {
            let repository = parsed_json
                .get("repository")
                .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let pr_number = parsed_json
                .get("number")
                .and_then(|n| n.as_i64())
                .unwrap_or(0);

            let action = parsed_json
                .get("action")
                .and_then(|a| a.as_str())
                .unwrap_or("opened")
                .to_string();

            // Emit git.pull_request event per docs/events.md
            emit_event(
                db,
                "git.pull_request",
                org_id_opt,
                None,
                None,
                None, // System actor
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "pr_number": pr_number,
                    "action": action,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "pull_request".to_string(),
                message: "Pull request webhook processed and git.pull_request event emitted"
                    .to_string(),
            })
        }
        other => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "ignored").await;
            Ok(WebhookDeliveryOutcome::Ignored {
                event_type: other.to_string(),
            })
        }
    }
}

/// Handles an incoming GitLab webhook delivery.
///
/// Steps:
/// 1. Verify GitLab signature via Standard Webhooks or Legacy token in constant time.
/// 2. Deduplicate delivery GUID using database unique constraint.
/// 3. If duplicate, return [`WebhookDeliveryOutcome::AlreadyProcessed`] (idempotent no-op).
/// 4. Dispatch event (`ping`, `push`, `tag_push`, `merge_request`) and emit appropriate domain event per `docs/events.md`.
///
/// Verified against GitLab webhook documentation.
pub async fn handle_gitlab_webhook(
    db: &Database,
    webhook_secret: Option<&str>,
    headers: GitLabWebhookHeaders<'_>,
    raw_body: &[u8],
) -> Result<WebhookDeliveryOutcome, GitConnectionError> {
    // 1. Webhook signature verification (Security Boundary)
    let secret = webhook_secret.ok_or(GitConnectionError::MissingSecret)?;
    verify_gitlab_webhook(secret, &headers, raw_body)?;

    // 2. Validate delivery GUID
    let delivery_guid = headers
        .delivery_id
        .or(headers.webhook_id)
        .filter(|d| !d.trim().is_empty())
        .map(|d| d.trim().to_string())
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let event_type = headers.event_type.unwrap_or("push").trim();

    // 3. Deduplicate delivery ID (Phase 6 Exit Gate: Idempotency)
    if repositories::delivery_exists(db, &delivery_guid).await? {
        return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
            delivery_id: delivery_guid,
        });
    }

    let payload_str = String::from_utf8_lossy(raw_body).to_string();
    let delivery = WebhookDelivery {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        provider: "gitlab".to_string(),
        delivery_id: delivery_guid.clone(),
        event_type: event_type.to_string(),
        payload: payload_str,
        status: "received".to_string(),
        created_at: Utc::now(),
    };

    let saved_delivery = match repositories::insert_delivery(db, delivery).await {
        Ok(d) => d,
        Err(_) => {
            return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
                delivery_id: delivery_guid,
            });
        }
    };

    // 4. Parse payload JSON
    let parsed_json: serde_json::Value = serde_json::from_slice(raw_body)
        .map_err(|e| GitConnectionError::InvalidPayload(e.to_string()))?;

    // Look up optional connection by project ID or path
    let project_id_str = parsed_json
        .get("project_id")
        .or_else(|| parsed_json.get("project").and_then(|p| p.get("id")))
        .and_then(|id| {
            if id.is_number() {
                Some(id.to_string())
            } else {
                id.as_str().map(|s| s.to_string())
            }
        });

    let connection_opt = if let Some(ref pid) = project_id_str {
        repositories::connection_by_provider_and_installation(db, "gitlab", pid).await?
    } else {
        None
    };

    let connection_public_id = connection_opt
        .as_ref()
        .map(|c| c.public_id.clone())
        .unwrap_or_else(|| "gitlab".to_string());

    let org_id_opt = connection_opt.as_ref().map(|c| c.organization_id.id);

    // 5. Handle event types
    match event_type {
        "ping" => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;
            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "ping".to_string(),
                message: "GitLab ping acknowledged successfully".to_string(),
            })
        }
        "push" | "tag_push" | "Push Hook" | "Tag Push Hook" => {
            let repository = parsed_json
                .get("project")
                .and_then(|p| p.get("path_with_namespace").or_else(|| p.get("name")))
                .or_else(|| parsed_json.get("repository").and_then(|r| r.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let git_ref = parsed_json
                .get("ref")
                .and_then(|r| r.as_str())
                .unwrap_or("refs/heads/main")
                .to_string();

            let commit_sha = parsed_json
                .get("after")
                .or_else(|| parsed_json.get("checkout_sha"))
                .and_then(|c| c.as_str())
                .unwrap_or("HEAD")
                .to_string();

            emit_event(
                db,
                "git.push",
                org_id_opt,
                None,
                None,
                None,
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "ref": git_ref,
                    "commit": commit_sha,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "push".to_string(),
                message: "GitLab push webhook processed and git.push event emitted".to_string(),
            })
        }
        "merge_request" | "Merge Request Hook" => {
            let repository = parsed_json
                .get("project")
                .and_then(|p| p.get("path_with_namespace").or_else(|| p.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let pr_number = parsed_json
                .get("object_attributes")
                .and_then(|a| a.get("iid").or_else(|| a.get("id")))
                .and_then(|n| n.as_i64())
                .unwrap_or(0);

            let action = parsed_json
                .get("object_attributes")
                .and_then(|a| a.get("action"))
                .and_then(|a| a.as_str())
                .unwrap_or("open")
                .to_string();

            emit_event(
                db,
                "git.pull_request",
                org_id_opt,
                None,
                None,
                None,
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "pr_number": pr_number,
                    "action": action,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "pull_request".to_string(),
                message:
                    "GitLab merge request webhook processed and git.pull_request event emitted"
                        .to_string(),
            })
        }
        other => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "ignored").await;
            Ok(WebhookDeliveryOutcome::Ignored {
                event_type: other.to_string(),
            })
        }
    }
}

/// Handles an incoming Bitbucket webhook delivery.
///
/// Steps:
/// 1. Verify `X-Hub-Signature` HMAC-SHA256 against raw body bytes in constant time.
///    (Bitbucket omits header when no secret is configured; missing signature is rejected).
/// 2. Deduplicate on `X-Request-UUID` GUID using database unique constraint.
/// 3. If duplicate, return [`WebhookDeliveryOutcome::AlreadyProcessed`] (idempotent no-op).
/// 4. Dispatch event (`ping`, `repo:push`, `pullrequest:created`, `pullrequest:updated`) and emit domain event per `docs/events.md`.
///
/// Verified against Bitbucket Cloud webhook documentation.
pub async fn handle_bitbucket_webhook(
    db: &Database,
    webhook_secret: Option<&str>,
    signature_header: Option<&str>,
    delivery_id_header: Option<&str>,
    event_type_header: Option<&str>,
    raw_body: &[u8],
) -> Result<WebhookDeliveryOutcome, GitConnectionError> {
    // 1. Webhook signature verification (Security Boundary)
    let secret = webhook_secret.ok_or(GitConnectionError::MissingSecret)?;
    verify_bitbucket_signature(secret, signature_header, raw_body)?;

    // 2. Validate delivery GUID header
    let delivery_guid = match delivery_id_header {
        Some(d) if !d.trim().is_empty() => d.trim(),
        _ => return Err(GitConnectionError::MissingDeliveryId),
    };

    let event_type = event_type_header.unwrap_or("repo:push").trim();

    // 3. Deduplicate delivery ID (Phase 6 Exit Gate: Idempotency)
    if repositories::delivery_exists(db, delivery_guid).await? {
        return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
            delivery_id: delivery_guid.to_string(),
        });
    }

    let payload_str = String::from_utf8_lossy(raw_body).to_string();
    let delivery = WebhookDelivery {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        provider: "bitbucket".to_string(),
        delivery_id: delivery_guid.to_string(),
        event_type: event_type.to_string(),
        payload: payload_str,
        status: "received".to_string(),
        created_at: Utc::now(),
    };

    let saved_delivery = match repositories::insert_delivery(db, delivery).await {
        Ok(d) => d,
        Err(_) => {
            return Ok(WebhookDeliveryOutcome::AlreadyProcessed {
                delivery_id: delivery_guid.to_string(),
            });
        }
    };

    // 4. Parse payload JSON
    let parsed_json: serde_json::Value = serde_json::from_slice(raw_body)
        .map_err(|e| GitConnectionError::InvalidPayload(e.to_string()))?;

    // Look up optional connection by repository UUID
    let repo_uuid_opt = parsed_json
        .get("repository")
        .and_then(|r| r.get("uuid"))
        .and_then(|u| u.as_str());

    let connection_opt = if let Some(uuid) = repo_uuid_opt {
        repositories::connection_by_provider_and_installation(db, "bitbucket", uuid).await?
    } else {
        None
    };

    let connection_public_id = connection_opt
        .as_ref()
        .map(|c| c.public_id.clone())
        .unwrap_or_else(|| "bitbucket".to_string());

    let org_id_opt = connection_opt.as_ref().map(|c| c.organization_id.id);

    // 5. Handle event types
    match event_type {
        "ping" => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;
            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "ping".to_string(),
                message: "Bitbucket ping acknowledged successfully".to_string(),
            })
        }
        "repo:push" | "push" => {
            let repository = parsed_json
                .get("repository")
                .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let (git_ref, commit_sha) = parsed_json
                .get("push")
                .and_then(|p| p.get("changes"))
                .and_then(|c| c.as_array())
                .and_then(|arr| arr.first())
                .and_then(|ch| ch.get("new"))
                .map(|new_obj| {
                    let branch = new_obj
                        .get("name")
                        .and_then(|n| n.as_str())
                        .unwrap_or("main");
                    let commit = new_obj
                        .get("target")
                        .and_then(|t| t.get("hash"))
                        .and_then(|h| h.as_str())
                        .unwrap_or("HEAD");
                    (format!("refs/heads/{branch}"), commit.to_string())
                })
                .unwrap_or_else(|| ("refs/heads/main".to_string(), "HEAD".to_string()));

            emit_event(
                db,
                "git.push",
                org_id_opt,
                None,
                None,
                None,
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "ref": git_ref,
                    "commit": commit_sha,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "push".to_string(),
                message: "Bitbucket push webhook processed and git.push event emitted".to_string(),
            })
        }
        "pullrequest:created" | "pullrequest:updated" | "pull_request" => {
            let repository = parsed_json
                .get("repository")
                .and_then(|r| r.get("full_name").or_else(|| r.get("name")))
                .and_then(|n| n.as_str())
                .unwrap_or("unknown")
                .to_string();

            let pr_number = parsed_json
                .get("pullrequest")
                .and_then(|p| p.get("id"))
                .and_then(|n| n.as_i64())
                .unwrap_or(0);

            let action = if event_type.contains("created") {
                "opened"
            } else if event_type.contains("updated") {
                "synchronize"
            } else {
                "opened"
            }
            .to_string();

            emit_event(
                db,
                "git.pull_request",
                org_id_opt,
                None,
                None,
                None,
                serde_json::json!({
                    "connection_id": connection_public_id,
                    "repository": repository,
                    "pr_number": pr_number,
                    "action": action,
                }),
            )
            .await;

            let _ = repositories::update_delivery_status(db, saved_delivery.id, "processed").await;

            Ok(WebhookDeliveryOutcome::Processed {
                event_type: "pull_request".to_string(),
                message:
                    "Bitbucket pull request webhook processed and git.pull_request event emitted"
                        .to_string(),
            })
        }
        other => {
            let _ = repositories::update_delivery_status(db, saved_delivery.id, "ignored").await;
            Ok(WebhookDeliveryOutcome::Ignored {
                event_type: other.to_string(),
            })
        }
    }
}
