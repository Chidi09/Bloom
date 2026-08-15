//! Serialization adapters for the `signing` app.

use chrono::Utc;
use serde_json::Value;

use super::contracts::{SigningIdentityResponse, WorkerSigningIdentity, WorkerSigningResponse};
use super::models::SigningIdentity;

/// Expiry warning threshold in days (30 days).
pub const EXPIRY_WARNING_DAYS: i64 = 30;

/// Checks whether a given expiration timestamp falls within the warning threshold (30 days) or has expired.
pub fn is_identity_expiring(expires_at: Option<chrono::DateTime<Utc>>) -> bool {
    match expires_at {
        Some(exp) => {
            let threshold = Utc::now() + chrono::Duration::days(EXPIRY_WARNING_DAYS);
            exp <= threshold
        }
        None => false,
    }
}

/// Serializes a [`SigningIdentity`] entity into its public API [`SigningIdentityResponse`] representation.
///
/// Ensures raw secret material and ciphertext are NEVER serialized.
pub fn serialize_signing_identity(
    identity: &SigningIdentity,
    organization_public_id: &str,
) -> SigningIdentityResponse {
    let metadata_value: Value =
        serde_json::from_str(&identity.metadata).unwrap_or_else(|_| serde_json::json!({}));

    SigningIdentityResponse {
        id: identity.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        platform: identity.platform.clone(),
        name: identity.name.clone(),
        kind: identity.kind.clone(),
        metadata: metadata_value,
        expires_at: identity.expires_at.map(|t| t.to_rfc3339()),
        is_expiring: is_identity_expiring(identity.expires_at),
        created_at: identity.created_at.to_rfc3339(),
    }
}

/// Serializes decrypted signing material for worker job execution bundles.
pub fn serialize_worker_signing_identities(
    identities: Vec<WorkerSigningIdentity>,
) -> WorkerSigningResponse {
    WorkerSigningResponse { identities }
}
