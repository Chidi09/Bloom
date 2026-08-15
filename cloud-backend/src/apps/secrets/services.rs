//! Business logic, transactional workflows, and domain rules for `secrets`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use serde_json::json;
use uuid::Uuid;

use super::contracts::{SecretCreateRequest, SecretUpdateRequest, WorkerSecret};
use super::errors::SecretError;
use super::models::{Secret, SecretVersion};
use super::repositories::{self, EnvironmentSummary, OrganizationSummary};
use crate::infra::crypto::Crypto;

/// Validate key name format:
/// - Must not be empty.
/// - Must not exceed 255 characters.
/// - Must start with an ASCII letter or underscore (no leading digits).
/// - Must only contain ASCII alphanumeric characters and underscores.
pub fn validate_key_format(key: &str) -> Result<(), SecretError> {
    if key.is_empty() {
        return Err(SecretError::InvalidKeyFormat(
            "Secret key cannot be empty.".to_string(),
        ));
    }
    if key.len() > 255 {
        return Err(SecretError::InvalidKeyFormat(
            "Secret key cannot exceed 255 characters.".to_string(),
        ));
    }

    let mut chars = key.chars();
    let first = chars.next().unwrap();
    if !first.is_ascii_alphabetic() && first != '_' {
        return Err(SecretError::InvalidKeyFormat(
            "Secret key must start with a letter or underscore, not a digit.".to_string(),
        ));
    }

    for c in chars {
        if !c.is_ascii_alphanumeric() && c != '_' {
            return Err(SecretError::InvalidKeyFormat(
                "Secret key must contain only alphanumeric characters and underscores.".to_string(),
            ));
        }
    }

    Ok(())
}

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

/// Emits an audit log record with redacted before/after snapshots for sensitive state changes.
/// Values and ciphertexts are NEVER recorded in the audit log.
pub async fn emit_audit_log(
    db: &Database,
    action: &str,
    organization_id: i64,
    actor_id: Option<i64>,
    resource_id: &str,
    before_snapshot: Option<serde_json::Value>,
    after_snapshot: Option<serde_json::Value>,
) {
    let payload = json!({
        "action": action,
        "resource_type": "secret",
        "resource_id": resource_id,
        "before": before_snapshot,
        "after": after_snapshot,
    });
    emit_event(
        db,
        &format!("audit.secret.{action}"),
        Some(organization_id),
        None,
        None,
        actor_id,
        payload,
    )
    .await;
}

/// Builds a redacted snapshot of a secret for audit logging.
pub fn redact_secret_snapshot(secret: &Secret, env_public_id: &str) -> serde_json::Value {
    json!({
        "id": secret.public_id,
        "environment_id": env_public_id,
        "key": secret.key,
        "is_json": secret.is_json,
        "version": secret.version,
        "value": "[REDACTED]",
    })
}

/// Create a new secret or update an existing one under `(environment_id, key)`.
pub async fn create_or_update_secret(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: SecretCreateRequest,
) -> Result<(Secret, EnvironmentSummary, OrganizationSummary), SecretError> {
    // 1. Resolve environment by public UUID and ensure it belongs to the active organization
    let env = repositories::environment_summary_by_public_id_and_org(
        db,
        &req.environment_id,
        organization_id,
    )
    .await?
    .ok_or(SecretError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SecretError::OrganizationNotFound)?;

    // 2. Validate key format
    let key = req.key.trim().to_string();
    validate_key_format(&key)?;

    // 3. Validate JSON if is_json is true
    if req.is_json {
        serde_json::from_str::<serde_json::Value>(&req.value)
            .map_err(|e| SecretError::InvalidJsonValue(e.to_string()))?;
    }

    // 4. Encrypt value with AES-256-GCM envelope encryption
    let encrypted_value = Crypto::encrypt(&req.value)?;

    // 5. Check if secret already exists for (environment_id, key)
    let existing_opt = repositories::secret_by_env_and_key(db, env.id, &key).await?;

    let now = Utc::now();
    if let Some(mut existing) = existing_opt {
        // Record before snapshot for audit log
        let before_snapshot = redact_secret_snapshot(&existing, &env.public_id);

        let new_version = existing.version + 1;
        existing.encrypted_value = encrypted_value.clone();
        existing.is_json = req.is_json;
        existing.version = new_version;
        existing.created_by_id = user_id;
        existing.created_at = now;

        repositories::update_secret(db, &existing).await?;

        // Record new version in history
        let secret_version = SecretVersion {
            id: 0,
            secret_id: ForeignKey::new(existing.id),
            encrypted_value,
            version: new_version,
            created_by_id: user_id,
            created_at: now,
        };
        repositories::insert_secret_version(db, secret_version).await?;

        // Emit secret.updated event
        emit_event(
            db,
            "secret.updated",
            Some(organization_id),
            None,
            None,
            Some(user_id),
            json!({
                "secret_id": existing.public_id,
                "environment_id": env.public_id,
                "key": existing.key,
                "version": new_version,
            }),
        )
        .await;

        let after_snapshot = redact_secret_snapshot(&existing, &env.public_id);
        emit_audit_log(
            db,
            "updated",
            organization_id,
            Some(user_id),
            &existing.public_id,
            Some(before_snapshot),
            Some(after_snapshot),
        )
        .await;

        Ok((existing, env, org))
    } else {
        // Insert new secret
        let new_secret = Secret {
            id: 0,
            public_id: Uuid::new_v4().to_string(),
            environment_id: ForeignKey::new(env.id),
            organization_id: ForeignKey::new(organization_id),
            key: key.clone(),
            encrypted_value: encrypted_value.clone(),
            is_json: req.is_json,
            version: 1,
            created_by_id: user_id,
            created_at: now,
        };

        let saved = repositories::insert_secret(db, new_secret).await?;

        // Record initial version 1 in history
        let secret_version = SecretVersion {
            id: 0,
            secret_id: ForeignKey::new(saved.id),
            encrypted_value,
            version: 1,
            created_by_id: user_id,
            created_at: now,
        };
        repositories::insert_secret_version(db, secret_version).await?;

        // Emit secret.created event
        emit_event(
            db,
            "secret.created",
            Some(organization_id),
            None,
            None,
            Some(user_id),
            json!({
                "secret_id": saved.public_id,
                "environment_id": env.public_id,
                "key": saved.key,
            }),
        )
        .await;

        let after_snapshot = redact_secret_snapshot(&saved, &env.public_id);
        emit_audit_log(
            db,
            "created",
            organization_id,
            Some(user_id),
            &saved.public_id,
            None,
            Some(after_snapshot),
        )
        .await;

        Ok((saved, env, org))
    }
}

/// Retrieve a secret by its public UUID within an organization.
pub async fn get_secret(
    db: &Database,
    organization_id: i64,
    secret_public_id: &str,
) -> Result<(Secret, EnvironmentSummary, OrganizationSummary), SecretError> {
    let secret = repositories::secret_by_public_id_and_org(db, secret_public_id, organization_id)
        .await?
        .ok_or(SecretError::SecretNotFound)?;

    let env = repositories::environment_summary_by_id(db, secret.environment_id.id)
        .await?
        .ok_or(SecretError::EnvironmentNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SecretError::OrganizationNotFound)?;

    Ok((secret, env, org))
}

/// List all secrets in an organization, optionally filtered by environment public UUID, with pagination and batched lookup.
pub async fn list_secrets(
    db: &Database,
    organization_id: i64,
    env_public_id: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<(Secret, EnvironmentSummary, OrganizationSummary)>, i64), SecretError> {
    let env_id = if let Some(env_pub_id) = env_public_id {
        let env =
            repositories::environment_summary_by_public_id_and_org(db, env_pub_id, organization_id)
                .await?
                .ok_or(SecretError::EnvironmentNotFound)?;
        Some(env.id)
    } else {
        None
    };

    let (secrets, total) =
        repositories::list_secrets_query(db, organization_id, env_id, limit, offset).await?;

    if secrets.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Hoist loop-invariant organization lookup
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SecretError::OrganizationNotFound)?;

    // 2. Batch-fetch all parent environment summaries in ONE query
    let mut env_ids: Vec<i64> = secrets.iter().map(|s| s.environment_id.id).collect();
    env_ids.sort_unstable();
    env_ids.dedup();
    let env_map = repositories::environment_summaries_by_ids(db, &env_ids).await?;

    let mut results = Vec::with_capacity(secrets.len());
    for secret in secrets {
        if let Some(env) = env_map.get(&secret.environment_id.id) {
            results.push((secret, env.clone(), org.clone()));
        }
    }

    Ok((results, total))
}

/// Partially update a secret's value and/or `is_json` flag.
pub async fn update_secret(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    secret_public_id: &str,
    req: SecretUpdateRequest,
) -> Result<(Secret, EnvironmentSummary, OrganizationSummary), SecretError> {
    let (mut secret, env, org) = get_secret(db, organization_id, secret_public_id).await?;
    let before_snapshot = redact_secret_snapshot(&secret, &env.public_id);

    let now = Utc::now();
    let mut updated = false;

    if let Some(new_val) = req.value {
        let target_is_json = req.is_json.unwrap_or(secret.is_json);
        if target_is_json {
            serde_json::from_str::<serde_json::Value>(&new_val)
                .map_err(|e| SecretError::InvalidJsonValue(e.to_string()))?;
        }

        let encrypted = Crypto::encrypt(&new_val)?;
        let new_version = secret.version + 1;

        secret.encrypted_value = encrypted.clone();
        secret.is_json = target_is_json;
        secret.version = new_version;
        secret.created_by_id = user_id;
        secret.created_at = now;

        repositories::update_secret(db, &secret).await?;

        let secret_version = SecretVersion {
            id: 0,
            secret_id: ForeignKey::new(secret.id),
            encrypted_value: encrypted,
            version: new_version,
            created_by_id: user_id,
            created_at: now,
        };
        repositories::insert_secret_version(db, secret_version).await?;

        updated = true;
    } else if let Some(is_json) = req.is_json {
        if is_json != secret.is_json {
            if is_json {
                // Decrypt and verify current value is valid JSON
                let plaintext = Crypto::decrypt(&secret.encrypted_value)?;
                serde_json::from_str::<serde_json::Value>(&plaintext)
                    .map_err(|e| SecretError::InvalidJsonValue(e.to_string()))?;
            }

            secret.is_json = is_json;
            secret.created_at = now;
            repositories::update_secret(db, &secret).await?;
            updated = true;
        }
    }

    if updated {
        emit_event(
            db,
            "secret.updated",
            Some(organization_id),
            None,
            None,
            Some(user_id),
            json!({
                "secret_id": secret.public_id,
                "environment_id": env.public_id,
                "key": secret.key,
                "version": secret.version,
            }),
        )
        .await;

        let after_snapshot = redact_secret_snapshot(&secret, &env.public_id);
        emit_audit_log(
            db,
            "updated",
            organization_id,
            Some(user_id),
            &secret.public_id,
            Some(before_snapshot),
            Some(after_snapshot),
        )
        .await;
    }

    Ok((secret, env, org))
}

/// Rollback a secret to a specific previous version.
pub async fn rollback_secret(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    secret_public_id: &str,
    target_version: i64,
) -> Result<(Secret, EnvironmentSummary, OrganizationSummary), SecretError> {
    let (mut secret, env, org) = get_secret(db, organization_id, secret_public_id).await?;
    let before_snapshot = redact_secret_snapshot(&secret, &env.public_id);

    // Look up historical target version
    let target_ver_record =
        repositories::secret_version_by_secret_and_version(db, secret.id, target_version)
            .await?
            .ok_or(SecretError::VersionNotFound)?;

    let now = Utc::now();
    let new_version = secret.version + 1;

    secret.encrypted_value = target_ver_record.encrypted_value.clone();
    secret.version = new_version;
    secret.created_by_id = user_id;
    secret.created_at = now;

    repositories::update_secret(db, &secret).await?;

    // Record this rollback as a new version point in history
    let new_history_entry = SecretVersion {
        id: 0,
        secret_id: ForeignKey::new(secret.id),
        encrypted_value: target_ver_record.encrypted_value,
        version: new_version,
        created_by_id: user_id,
        created_at: now,
    };
    repositories::insert_secret_version(db, new_history_entry).await?;

    // Emit secret.rolled_back event
    emit_event(
        db,
        "secret.rolled_back",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        json!({
            "secret_id": secret.public_id,
            "environment_id": env.public_id,
            "key": secret.key,
            "to_version": target_version,
        }),
    )
    .await;

    let after_snapshot = redact_secret_snapshot(&secret, &env.public_id);
    emit_audit_log(
        db,
        "rolled_back",
        organization_id,
        Some(user_id),
        &secret.public_id,
        Some(before_snapshot),
        Some(after_snapshot),
    )
    .await;

    Ok((secret, env, org))
}

/// Delete a secret and emit audit & domain events.
pub async fn delete_secret(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    secret_public_id: &str,
) -> Result<(), SecretError> {
    let (secret, env, _) = get_secret(db, organization_id, secret_public_id).await?;
    let before_snapshot = redact_secret_snapshot(&secret, &env.public_id);

    repositories::delete_secret_by_id(db, secret.id).await?;

    // Emit secret.deleted event
    emit_event(
        db,
        "secret.deleted",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        json!({
            "secret_id": secret.public_id,
            "environment_id": env.public_id,
            "key": secret.key,
        }),
    )
    .await;

    emit_audit_log(
        db,
        "deleted",
        organization_id,
        Some(user_id),
        &secret.public_id,
        Some(before_snapshot),
        None,
    )
    .await;

    Ok(())
}

/// Decrypts a single secret for an authenticated worker presenting matching job claims.
pub async fn decrypt_for_worker(
    db: &Database,
    secret_public_id: &str,
    expected_organization_id: i64,
    expected_environment_id: i64,
) -> Result<String, SecretError> {
    let secret =
        repositories::secret_by_public_id_and_org(db, secret_public_id, expected_organization_id)
            .await?
            .ok_or(SecretError::SecretNotFound)?;

    if secret.environment_id.id != expected_environment_id {
        return Err(SecretError::Forbidden);
    }

    let plaintext = Crypto::decrypt(&secret.encrypted_value)?;
    Ok(plaintext)
}

/// Decrypts all secrets for an environment for a worker job execution bundle.
pub async fn decrypt_environment_secrets_for_worker(
    db: &Database,
    environment_id: i64,
    expected_organization_id: i64,
) -> Result<Vec<WorkerSecret>, SecretError> {
    let secrets =
        repositories::secrets_for_environment(db, environment_id, expected_organization_id).await?;

    let mut decrypted = Vec::with_capacity(secrets.len());
    for s in secrets {
        let plaintext = Crypto::decrypt(&s.encrypted_value)?;
        decrypted.push(WorkerSecret {
            key: s.key,
            value: plaintext,
            is_json: s.is_json,
        });
    }

    Ok(decrypted)
}
