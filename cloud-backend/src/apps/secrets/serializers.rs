//! Serialization helpers for transforming secret models into wire DTOs.

use super::contracts::{SecretResponse, WorkerSecret, WorkerSecretsResponse};
use super::models::Secret;

/// Serializes a `Secret` model into its public API representation.
///
/// NOTE: The secret's plaintext value and ciphertext are NEVER serialized here.
pub fn serialize_secret(
    secret: &Secret,
    environment_public_id: &str,
    organization_public_id: &str,
) -> SecretResponse {
    SecretResponse {
        id: secret.public_id.clone(),
        environment_id: environment_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        key: secret.key.clone(),
        is_json: secret.is_json,
        version: secret.version,
        updated_at: secret.created_at.to_rfc3339(),
    }
}

/// Serializes decrypted secrets for worker execution bundles.
pub fn serialize_worker_secrets(env_vars: Vec<WorkerSecret>) -> WorkerSecretsResponse {
    WorkerSecretsResponse { env_vars }
}
