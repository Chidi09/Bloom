//! Serialization adapters for the `credentials` app.

use super::contracts::CredentialResponse;
use super::models::Credential;

/// Serializes a [`Credential`] entity into its public API [`CredentialResponse`] representation.
///
/// Under no circumstances is the encrypted ciphertext or decrypted secret returned.
pub fn serialize_credential(
    credential: &Credential,
    organization_public_id: &str,
) -> CredentialResponse {
    let metadata_value: serde_json::Value =
        serde_json::from_str(&credential.metadata).unwrap_or_else(|_| serde_json::json!({}));

    CredentialResponse {
        id: credential.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        provider: credential.provider.clone(),
        name: credential.name.clone(),
        metadata: metadata_value,
        expires_at: credential.expires_at.map(|t| t.to_rfc3339()),
        last_used_at: credential.last_used_at.map(|t| t.to_rfc3339()),
        created_at: credential.created_at.to_rfc3339(),
    }
}
