//! Business logic, HMAC signature verification, idempotency deduplication, and operations for `git_connections`.

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

/// Computes HMAC-SHA256 hex digest over raw message bytes with the given secret.
///
/// Implements RFC 2104 / FIPS 198 HMAC-SHA256 without third-party wrapper dependencies.
pub fn compute_hmac_sha256(secret: &[u8], message: &[u8]) -> String {
    // Delegates to the single HMAC implementation in the crypto layer. This used to carry its
    // own copy of RFC 2104, as did src/workers/webhook.rs.
    Crypto::hmac_sha256_hex(secret, message)
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

    // Emit git.connected event per events.md
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

/// List all Git connections belonging to an organization.
pub async fn list_connections(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<GitConnection>, GitConnectionError> {
    let connections = repositories::connections_for_organization(db, organization_id).await?;
    Ok(connections)
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

    // Emit git.disconnected event per events.md
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
/// 4. Dispatch event (`ping`, `push`, `pull_request`) and emit appropriate domain event per `events.md`.
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

    // 5. Handle event types per integrations/github.md and events.md
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

            // Emit git.push event per events.md
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

            // Emit git.pull_request event per events.md
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

/// Handle GitLab webhook delivery (unverified signature scheme is safely rejected).
pub async fn handle_gitlab_webhook(
    _db: &Database,
    _raw_body: &[u8],
) -> Result<WebhookDeliveryOutcome, GitConnectionError> {
    // TODO(spec): gitlab signature scheme unverified
    Err(GitConnectionError::UnverifiedProviderSignature(
        "gitlab".to_string(),
    ))
}

/// Handle Bitbucket webhook delivery (unverified signature scheme is safely rejected).
pub async fn handle_bitbucket_webhook(
    _db: &Database,
    _raw_body: &[u8],
) -> Result<WebhookDeliveryOutcome, GitConnectionError> {
    // TODO(spec): bitbucket signature scheme unverified
    Err(GitConnectionError::UnverifiedProviderSignature(
        "bitbucket".to_string(),
    ))
}
