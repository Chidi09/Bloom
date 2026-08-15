//! Business logic, transactional workflows, and domain rules for `signing`.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::ForeignKey;
use serde_json::json;
use uuid::Uuid;

use super::contracts::{
    SigningIdentityCreateRequest, SigningIdentityMetadata, WorkerSigningIdentity,
};
use super::errors::SigningError;
use super::models::SigningIdentity;
use super::repositories::{self, OrganizationSummary};
use super::serializers::is_identity_expiring;
use crate::infra::crypto::Crypto;

/// Emits an audit log record with redacted before/after snapshots for sensitive state changes.
/// Values, raw material, and ciphertexts are NEVER recorded in the audit log.
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
        "resource_type": "signing_identity",
        "resource_id": resource_id,
        "before": before_snapshot,
        "after": after_snapshot,
    });
    crate::apps::events::emit(
        db,
        &format!("audit.signing.{action}"),
        Some(organization_id),
        None,
        None,
        actor_id,
        payload,
    )
    .await;
}

/// Builds a redacted snapshot of a signing identity for audit logging.
pub fn redact_signing_snapshot(
    identity: &SigningIdentity,
    org_public_id: &str,
) -> serde_json::Value {
    let metadata_val: serde_json::Value =
        serde_json::from_str(&identity.metadata).unwrap_or_else(|_| json!({}));

    json!({
        "id": identity.public_id,
        "organization_id": org_public_id,
        "platform": identity.platform,
        "name": identity.name,
        "kind": identity.kind,
        "metadata": metadata_val,
        "expires_at": identity.expires_at.map(|t| t.to_rfc3339()),
        "material": "[REDACTED]",
    })
}

/// Normalized, validated fields extracted from a `SigningIdentityCreateRequest`.
///
/// A named struct rather than a tuple: four of the five fields are `String`, so positional
/// destructuring silently tolerates a swapped pair.
#[derive(Debug, Clone)]
pub struct ValidatedSigningRequest {
    /// Lowercased platform, `android` or `ios`.
    pub platform: String,
    /// Trimmed display name.
    pub name: String,
    /// Lowercased identity kind.
    pub kind: String,
    /// Metadata serialized to a JSON string for storage.
    pub metadata: String,
    /// Parsed expiry timestamp, if the request supplied one.
    pub expires_at: Option<DateTime<Utc>>,
}

/// Validates platform, kind, metadata coherence, and expires_at parsing.
pub fn validate_signing_request(
    req: &SigningIdentityCreateRequest,
) -> Result<ValidatedSigningRequest, SigningError> {
    let platform = req.platform.trim().to_lowercase();
    if platform != "android" && platform != "ios" {
        return Err(SigningError::InvalidPlatform(
            "Platform must be 'android' or 'ios'.".to_string(),
        ));
    }

    let kind = req.kind.trim().to_lowercase();
    match kind.as_str() {
        "keystore" | "certificate" | "provisioning_profile" | "api_key" => {}
        _ => {
            return Err(SigningError::InvalidKind(
                "Kind must be 'keystore', 'certificate', 'provisioning_profile', or 'api_key'."
                    .to_string(),
            ));
        }
    }

    // Coherence check between kind and metadata variant
    match (&req.metadata, kind.as_str()) {
        (SigningIdentityMetadata::Keystore { .. }, "keystore") => {}
        (SigningIdentityMetadata::Certificate { .. }, "certificate") => {}
        (SigningIdentityMetadata::ProvisioningProfile { .. }, "provisioning_profile") => {}
        (SigningIdentityMetadata::ApiKey { .. }, "api_key") => {}
        _ => {
            return Err(SigningError::MetadataMismatch(format!(
                "Metadata kind variant does not match kind field '{kind}'"
            )));
        }
    }

    let name = req.name.trim();
    if name.is_empty() {
        return Err(SigningError::ValidationError(
            "Name cannot be empty.".to_string(),
        ));
    }
    if name.len() > 255 {
        return Err(SigningError::ValidationError(
            "Name cannot exceed 255 characters.".to_string(),
        ));
    }

    let raw_material = req.material.trim();
    if raw_material.is_empty() {
        return Err(SigningError::InvalidMaterial(
            "Material cannot be empty.".to_string(),
        ));
    }

    let metadata_str = serde_json::to_string(&req.metadata)
        .map_err(|e| SigningError::ValidationError(e.to_string()))?;

    let parsed_expiry = if let Some(ref exp_str) = req.expires_at {
        let trimmed_exp = exp_str.trim();
        if trimmed_exp.is_empty() {
            None
        } else {
            let dt = DateTime::parse_from_rfc3339(trimmed_exp)
                .map(|d| d.with_timezone(&Utc))
                .or_else(|_| {
                    chrono::NaiveDateTime::parse_from_str(trimmed_exp, "%Y-%m-%d %H:%M:%S")
                        .map(|naive| DateTime::<Utc>::from_naive_utc_and_offset(naive, Utc))
                })
                .or_else(|_| {
                    chrono::NaiveDate::parse_from_str(trimmed_exp, "%Y-%m-%d")
                        .map(|d| d.and_hms_opt(0, 0, 0).unwrap())
                        .map(|naive| DateTime::<Utc>::from_naive_utc_and_offset(naive, Utc))
                })
                .map_err(|e| {
                    SigningError::InvalidExpiryDate(format!(
                        "Could not parse '{trimmed_exp}' as ISO-8601 / RFC-3339 timestamp: {e}"
                    ))
                })?;
            Some(dt)
        }
    } else {
        None
    };

    Ok(ValidatedSigningRequest {
        platform,
        name: name.to_string(),
        kind,
        metadata: metadata_str,
        expires_at: parsed_expiry,
    })
}

/// Upload and store a new encrypted `SigningIdentity`.
pub async fn upload_signing_identity(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: SigningIdentityCreateRequest,
) -> Result<(SigningIdentity, OrganizationSummary), SigningError> {
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SigningError::OrganizationNotFound)?;

    let ValidatedSigningRequest {
        platform,
        name,
        kind,
        metadata: metadata_str,
        expires_at,
    } = validate_signing_request(&req)?;

    // Encrypt material using AES-256-GCM envelope encryption
    let encrypted_material = Crypto::encrypt(req.material.trim())?;

    let now = Utc::now();
    let identity = SigningIdentity {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        platform: platform.clone(),
        name: name.clone(),
        kind: kind.clone(),
        encrypted_material,
        metadata: metadata_str,
        expires_at,
        created_at: now,
        updated_at: now,
    };

    let saved = repositories::insert_signing_identity(db, identity).await?;

    // Emit signing.created event
    crate::apps::events::emit(
        db,
        "signing.created",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        json!({
            "signing_id": saved.public_id,
            "platform": saved.platform,
            "name": saved.name,
        }),
    )
    .await;

    // If already expiring or expired at creation time, emit signing.expiring warning event
    if is_identity_expiring(saved.expires_at) {
        crate::apps::events::emit(
            db,
            "signing.expiring",
            Some(organization_id),
            None,
            None,
            Some(user_id),
            json!({
                "signing_id": saved.public_id,
                "platform": saved.platform,
                "expires_at": saved.expires_at.map(|t| t.to_rfc3339()),
            }),
        )
        .await;
    }

    // Emit audit log
    let after_snapshot = redact_signing_snapshot(&saved, &org.public_id);
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

    Ok((saved, org))
}

/// Retrieve a single `SigningIdentity` scoped to an organization.
pub async fn get_signing_identity(
    db: &Database,
    organization_id: i64,
    identity_public_id: &str,
) -> Result<(SigningIdentity, OrganizationSummary), SigningError> {
    let identity = repositories::signing_identity_by_public_id_and_org(
        db,
        identity_public_id,
        organization_id,
    )
    .await?
    .ok_or(SigningError::SigningIdentityNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SigningError::OrganizationNotFound)?;

    Ok((identity, org))
}

/// List all `SigningIdentity` records for an organization (optionally filtered by platform), with pagination.
pub async fn list_signing_identities(
    db: &Database,
    organization_id: i64,
    platform_filter: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<(SigningIdentity, OrganizationSummary)>, i64), SigningError> {
    let clean_p = platform_filter.map(|p| p.trim().to_lowercase());
    let (identities, total) = repositories::list_signing_identities_query(
        db,
        organization_id,
        clean_p.as_deref(),
        limit,
        offset,
    )
    .await?;

    if identities.is_empty() {
        return Ok((Vec::new(), total));
    }

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(SigningError::OrganizationNotFound)?;

    let mut results = Vec::with_capacity(identities.len());
    for item in identities {
        results.push((item, org.clone()));
    }

    Ok((results, total))
}

/// Delete a `SigningIdentity` record and emit audit & domain events.
pub async fn delete_signing_identity(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    identity_public_id: &str,
) -> Result<(), SigningError> {
    let (identity, org) = get_signing_identity(db, organization_id, identity_public_id).await?;
    let before_snapshot = redact_signing_snapshot(&identity, &org.public_id);

    repositories::delete_signing_identity_by_id(db, identity.id).await?;

    // Emit signing.deleted event
    crate::apps::events::emit(
        db,
        "signing.deleted",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        json!({
            "signing_id": identity.public_id,
            "platform": identity.platform,
            "name": identity.name,
        }),
    )
    .await;

    // Emit audit log
    emit_audit_log(
        db,
        "deleted",
        organization_id,
        Some(user_id),
        &identity.public_id,
        Some(before_snapshot),
        None,
    )
    .await;

    Ok(())
}

/// Decrypts a single signing identity's material for an authenticated worker job.
pub async fn decrypt_for_worker(
    db: &Database,
    identity_public_id: &str,
    expected_organization_id: i64,
) -> Result<WorkerSigningIdentity, SigningError> {
    let identity = repositories::signing_identity_by_public_id_and_org(
        db,
        identity_public_id,
        expected_organization_id,
    )
    .await?
    .ok_or(SigningError::SigningIdentityNotFound)?;

    let decrypted_material = Crypto::decrypt(&identity.encrypted_material)?;
    let metadata_value: serde_json::Value =
        serde_json::from_str(&identity.metadata).unwrap_or_else(|_| json!({}));

    Ok(WorkerSigningIdentity {
        id: identity.public_id,
        platform: identity.platform,
        name: identity.name,
        kind: identity.kind,
        material: decrypted_material,
        metadata: metadata_value,
        expires_at: identity.expires_at.map(|t| t.to_rfc3339()),
    })
}

/// Decrypts all signing identities for an organization and platform for a worker job.
pub async fn decrypt_signing_identities_for_worker(
    db: &Database,
    organization_id: i64,
    platform: Option<&str>,
) -> Result<Vec<WorkerSigningIdentity>, SigningError> {
    let identities = if let Some(p) = platform {
        repositories::signing_identities_for_org_and_platform(db, organization_id, p).await?
    } else {
        repositories::signing_identities_for_organization(db, organization_id).await?
    };

    let mut decrypted_list = Vec::with_capacity(identities.len());
    for item in identities {
        let decrypted_material = Crypto::decrypt(&item.encrypted_material)?;
        let metadata_value: serde_json::Value =
            serde_json::from_str(&item.metadata).unwrap_or_else(|_| json!({}));

        decrypted_list.push(WorkerSigningIdentity {
            id: item.public_id,
            platform: item.platform,
            name: item.name,
            kind: item.kind,
            material: decrypted_material,
            metadata: metadata_value,
            expires_at: item.expires_at.map(|t| t.to_rfc3339()),
        });
    }

    Ok(decrypted_list)
}

/// Checks all signing identities in an organization and emits `signing.expiring` warning events for those within 30 days of expiration.
pub async fn check_and_emit_expiry_warnings(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<SigningIdentity>, SigningError> {
    let identities = repositories::signing_identities_for_organization(db, organization_id).await?;
    let mut expiring = Vec::new();

    for identity in identities {
        if is_identity_expiring(identity.expires_at) {
            crate::apps::events::emit(
                db,
                "signing.expiring",
                Some(organization_id),
                None,
                None,
                None,
                json!({
                    "signing_id": identity.public_id,
                    "platform": identity.platform,
                    "expires_at": identity.expires_at.map(|t| t.to_rfc3339()),
                }),
            )
            .await;
            expiring.push(identity);
        }
    }

    Ok(expiring)
}
