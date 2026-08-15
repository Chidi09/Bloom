//! Serialization adapters for the `git_connections` app.

use super::contracts::GitConnectionResponse;
use super::models::GitConnection;

/// Serializes a [`GitConnection`] entity into its public API [`GitConnectionResponse`] representation.
///
/// Under no circumstances is the encrypted access token or decrypted secret returned.
pub fn serialize_git_connection(
    connection: &GitConnection,
    organization_public_id: &str,
) -> GitConnectionResponse {
    let metadata_value: serde_json::Value =
        serde_json::from_str(&connection.metadata).unwrap_or_else(|_| serde_json::json!({}));

    GitConnectionResponse {
        id: connection.public_id.clone(),
        organization_id: organization_public_id.to_string(),
        provider: connection.provider.clone(),
        installation_id: connection.installation_id.clone(),
        metadata: metadata_value,
        created_at: connection.created_at.to_rfc3339(),
    }
}
