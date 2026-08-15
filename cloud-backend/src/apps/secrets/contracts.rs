//! Data Transfer Objects (DTOs) and API request/response contracts for `secrets`.

use serde::{Deserialize, Serialize};

/// Payload to create or update an environment secret.
#[derive(Debug, Clone, Deserialize)]
pub struct SecretCreateRequest {
    /// Public UUID of the target environment.
    pub environment_id: String,

    /// Key identifier (e.g. `API_TOKEN`, `DATABASE_URL`).
    pub key: String,

    /// Plaintext value in request payload (encrypted before storage).
    pub value: String,

    /// Whether the value represents a valid JSON string.
    #[serde(default)]
    pub is_json: bool,
}

/// Payload for partial update of a secret.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct SecretUpdateRequest {
    /// New plaintext value to encrypt and store as a new version.
    pub value: Option<String>,

    /// Update whether the value is treated as JSON.
    pub is_json: Option<bool>,
}

/// Payload to rollback a secret to a previous version.
#[derive(Debug, Clone, Deserialize)]
pub struct SecretRollbackRequest {
    /// Target version number to restore.
    pub version: i64,
}

/// Public API response representation for a secret (metadata only; value is NEVER returned).
#[derive(Debug, Clone, Serialize)]
pub struct SecretResponse {
    /// Public UUID identifier of the secret.
    pub id: String,

    /// Public UUID identifier of the environment.
    pub environment_id: String,

    /// Public UUID identifier of the organization.
    pub organization_id: String,

    /// Secret key name.
    pub key: String,

    /// Whether the value represents JSON.
    pub is_json: bool,

    /// Current version number.
    pub version: i64,

    /// ISO 8601 formatted timestamp of last update.
    pub updated_at: String,
}

/// Decrypted secret representation delivered strictly to internal worker pools.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerSecret {
    /// Secret key name.
    pub key: String,

    /// Decrypted plaintext secret value.
    pub value: String,

    /// Whether the value represents JSON.
    pub is_json: bool,
}

/// Response payload containing all decrypted environment secrets for a worker job.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerSecretsResponse {
    /// Collection of decrypted environment variables / secrets.
    pub env_vars: Vec<WorkerSecret>,
}
