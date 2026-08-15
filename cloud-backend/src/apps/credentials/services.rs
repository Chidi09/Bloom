//! Business logic, encryption, validation, and operations for `credentials`.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{CredentialCreateRequest, CredentialMetadata};
use super::errors::CredentialError;
use super::models::Credential;
use super::repositories;
use crate::infra::crypto::Crypto;

/// Allowed platform provider identifiers.
pub const ALLOWED_PROVIDERS: &[&str] = &[
    "apple",
    "google_play",
    "shorebird",
    "github",
    "gitlab",
    "bitbucket",
];

/// Validates that the provider is supported and matches the provided metadata structure.
pub fn validate_provider_and_metadata(
    provider: &str,
    metadata: &CredentialMetadata,
) -> Result<String, CredentialError> {
    if !ALLOWED_PROVIDERS.contains(&provider) {
        return Err(CredentialError::InvalidProvider(provider.to_string()));
    }

    match (provider, metadata) {
        (
            "apple",
            CredentialMetadata::Apple {
                key_id,
                issuer_id,
                team_id,
            },
        ) => {
            if key_id.trim().is_empty() || issuer_id.trim().is_empty() || team_id.trim().is_empty()
            {
                return Err(CredentialError::InvalidMetadata(
                    "Apple credentials require non-empty key_id, issuer_id, and team_id"
                        .to_string(),
                ));
            }
        }
        ("google_play", CredentialMetadata::GooglePlay { client_email }) => {
            if client_email.trim().is_empty() || !client_email.contains('@') {
                return Err(CredentialError::InvalidMetadata(
                    "Google Play credentials require a valid client_email".to_string(),
                ));
            }
        }
        ("shorebird", CredentialMetadata::Shorebird { app_id }) => {
            if app_id.trim().is_empty() {
                return Err(CredentialError::InvalidMetadata(
                    "Shorebird credentials require a non-empty app_id".to_string(),
                ));
            }
        }
        ("github", CredentialMetadata::GitHub { installation_id }) => {
            if installation_id.trim().is_empty() {
                return Err(CredentialError::InvalidMetadata(
                    "GitHub credentials require a non-empty installation_id".to_string(),
                ));
            }
        }
        ("gitlab", CredentialMetadata::GitLab { application_id }) => {
            if application_id.trim().is_empty() {
                return Err(CredentialError::InvalidMetadata(
                    "GitLab credentials require a non-empty application_id".to_string(),
                ));
            }
        }
        ("bitbucket", CredentialMetadata::Bitbucket { workspace }) => {
            if workspace.trim().is_empty() {
                return Err(CredentialError::InvalidMetadata(
                    "Bitbucket credentials require a non-empty workspace".to_string(),
                ));
            }
        }
        _ => {
            return Err(CredentialError::InvalidMetadata(format!(
                "Metadata variant does not match provider '{provider}'"
            )));
        }
    }

    serde_json::to_string(metadata).map_err(|e| CredentialError::InvalidMetadata(e.to_string()))
}

/// Create a new encrypted platform credential within an organization.
pub async fn create_credential(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: CredentialCreateRequest,
) -> Result<Credential, CredentialError> {
    let name = req.name.trim();
    if name.is_empty() {
        return Err(CredentialError::ValidationError(
            "Name cannot be empty".to_string(),
        ));
    }

    let token = req.token.trim();
    if token.is_empty() {
        return Err(CredentialError::InvalidToken(
            "Token cannot be empty".to_string(),
        ));
    }

    if repositories::credential_name_exists_in_org(db, organization_id, name).await? {
        return Err(CredentialError::NameTaken);
    }

    let metadata_json = validate_provider_and_metadata(&req.provider, &req.metadata)?;

    let parsed_expires_at = if let Some(ref exp_str) = req.expires_at {
        let dt = DateTime::parse_from_rfc3339(exp_str)
            .map_err(|e| {
                CredentialError::ValidationError(format!("Invalid expires_at format: {e}"))
            })?
            .with_timezone(&Utc);
        Some(dt)
    } else {
        None
    };

    let encrypted_token = Crypto::encrypt(token)?;

    let credential = Credential {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        provider: req.provider,
        name: name.to_string(),
        encrypted_token,
        metadata: metadata_json,
        expires_at: parsed_expires_at,
        last_used_at: None,
        created_by_id: user_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_credential(db, credential).await?;

    crate::apps::events::emit(
        db,
        "credential.created",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        serde_json::json!({
            "credential_id": saved.public_id,
            "provider": saved.provider,
        }),
    )
    .await;

    Ok(saved)
}

/// List all credentials belonging to an organization, with optional pagination.
pub async fn list_credentials_for_organization(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Credential>, i64), CredentialError> {
    let (credentials, total) =
        repositories::list_credentials_query(db, organization_id, limit, offset).await?;
    Ok((credentials, total))
}

/// Retrieve a single credential by public UUID and verify organization scoping.
pub async fn get_credential(
    db: &Database,
    organization_id: i64,
    public_id: &str,
) -> Result<Credential, CredentialError> {
    repositories::credential_by_public_id_and_org(db, public_id, organization_id)
        .await?
        .ok_or(CredentialError::CredentialNotFound)
}

/// Delete a credential vault entry.
pub async fn delete_credential(
    db: &Database,
    credential: &Credential,
) -> Result<(), CredentialError> {
    repositories::delete_credential_by_id(db, credential.id).await?;

    crate::apps::events::emit(
        db,
        "credential.deleted",
        Some(credential.organization_id.id),
        None,
        None,
        None,
        serde_json::json!({
            "credential_id": credential.public_id,
            "provider": credential.provider,
        }),
    )
    .await;

    Ok(())
}

/// Test a credential connection without leaking any part of the secret.
pub async fn test_credential(
    db: &Database,
    credential: &Credential,
) -> Result<String, CredentialError> {
    // 1. Decrypt token to verify decryption succeeds and ciphertext is not corrupted
    let raw_token = Crypto::decrypt(&credential.encrypted_token).map_err(|e| {
        CredentialError::ValidationFailed(format!("Decryption verification failed: {e}"))
    })?;

    if raw_token.trim().is_empty() {
        return Err(CredentialError::ValidationFailed(
            "Decrypted token is empty".to_string(),
        ));
    }

    // 2. Validate metadata JSON parsing
    let metadata: CredentialMetadata = serde_json::from_str(&credential.metadata).map_err(|e| {
        CredentialError::ValidationFailed(format!("Invalid metadata structure: {e}"))
    })?;

    // 3. Provider-specific offline validation checks (simulated connection test)
    match (&credential.provider[..], &metadata) {
        (
            "apple",
            CredentialMetadata::Apple {
                key_id,
                issuer_id,
                team_id,
            },
        ) => {
            if key_id.len() < 2 || issuer_id.len() < 2 || team_id.len() < 2 {
                return Err(CredentialError::ValidationFailed(
                    "Invalid Apple App Store Connect key parameters".to_string(),
                ));
            }
        }
        ("google_play", CredentialMetadata::GooglePlay { client_email }) => {
            if !client_email.contains('@') {
                return Err(CredentialError::ValidationFailed(
                    "Invalid Google Play service account email".to_string(),
                ));
            }
        }
        ("shorebird", CredentialMetadata::Shorebird { app_id }) => {
            if app_id.is_empty() {
                return Err(CredentialError::ValidationFailed(
                    "Invalid Shorebird app ID".to_string(),
                ));
            }
        }
        ("github", CredentialMetadata::GitHub { installation_id }) => {
            if installation_id.is_empty() {
                return Err(CredentialError::ValidationFailed(
                    "Invalid GitHub App installation ID".to_string(),
                ));
            }
        }
        ("gitlab", CredentialMetadata::GitLab { application_id }) => {
            if application_id.is_empty() {
                return Err(CredentialError::ValidationFailed(
                    "Invalid GitLab application ID".to_string(),
                ));
            }
        }
        ("bitbucket", CredentialMetadata::Bitbucket { workspace }) => {
            if workspace.is_empty() {
                return Err(CredentialError::ValidationFailed(
                    "Invalid Bitbucket workspace".to_string(),
                ));
            }
        }
        (other, _) => {
            return Err(CredentialError::ValidationFailed(format!(
                "Unsupported provider for connection testing: {other}"
            )));
        }
    }

    // 4. Update last_used_at timestamp on successful verification
    let now = Utc::now();
    let _ = repositories::update_credential_last_used(db, credential.id, now).await;

    crate::apps::events::emit(
        db,
        "credential.tested",
        Some(credential.organization_id.id),
        None,
        None,
        None,
        serde_json::json!({
            "credential_id": credential.public_id,
            "provider": credential.provider,
            "success": true,
        }),
    )
    .await;

    Ok(format!(
        "Successfully validated {} credentials",
        credential.provider
    ))
}

/// Internal helper for workers to decrypt a credential token for background jobs.
pub async fn decrypt_for_worker(
    db: &Database,
    credential_id: i64,
) -> Result<String, CredentialError> {
    let credential = repositories::credential_by_id(db, credential_id)
        .await?
        .ok_or(CredentialError::CredentialNotFound)?;

    let now = Utc::now();
    let _ = repositories::update_credential_last_used(db, credential.id, now).await;

    Crypto::decrypt(&credential.encrypted_token).map_err(|e| CredentialError::Crypto(e.to_string()))
}
