//! Request and response data contracts for the `signing` app.

use serde::{Deserialize, Serialize};

/// Structured metadata for different types of signing identities.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum SigningIdentityMetadata {
    /// Android keystore metadata.
    #[serde(rename = "keystore")]
    Keystore {
        /// Key alias within the keystore.
        alias: String,
    },
    /// iOS signing certificate metadata.
    #[serde(rename = "certificate")]
    Certificate {
        /// SHA-1 or SHA-256 fingerprint / thumbprint.
        fingerprint: String,
    },
    /// iOS provisioning profile metadata.
    #[serde(rename = "provisioning_profile")]
    ProvisioningProfile {
        /// App bundle ID (e.g. `com.example.app`).
        bundle_id: String,
        /// Profile UUID assigned by Apple.
        uuid: String,
    },
    /// App Store Connect API Key metadata.
    #[serde(rename = "api_key")]
    ApiKey {
        /// Key ID (e.g. `2X9R4HXF34`).
        key_id: String,
        /// Issuer ID UUID (e.g. `57246542-96fe-1a63-e053-0824d011072a`).
        issuer_id: String,
        /// Team ID (e.g. `A1B2C3D4E5`).
        team_id: String,
    },
}

/// Payload to upload/create a new signing identity.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct SigningIdentityCreateRequest {
    /// Target platform (`android` or `ios`).
    pub platform: String,
    /// Human-readable label for this signing material.
    pub name: String,
    /// Kind of signing material (`keystore`, `certificate`, `provisioning_profile`, `api_key`).
    pub kind: String,
    /// Base64-encoded binary or textual signing file content.
    pub material: String,
    /// Typed metadata describing the signing identity.
    pub metadata: SigningIdentityMetadata,
    /// Optional ISO-8601 expiration date string.
    pub expires_at: Option<String>,
}

/// Public API response representation for a signing identity.
/// NOTE: Raw material and encrypted ciphertext are NEVER exposed here.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SigningIdentityResponse {
    /// Public UUID identifier.
    pub id: String,
    /// Public UUID identifier of the enclosing organization.
    pub organization_id: String,
    /// Target platform (`android` or `ios`).
    pub platform: String,
    /// Human-readable name.
    pub name: String,
    /// Kind of signing material.
    pub kind: String,
    /// Metadata payload (fingerprints, bundle IDs, aliases, team ID, etc.).
    pub metadata: serde_json::Value,
    /// Optional ISO-8601 formatted expiration timestamp.
    pub expires_at: Option<String>,
    /// Whether this signing identity is expiring soon or expired (dashboard warning trigger).
    pub is_expiring: bool,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Decrypted signing material delivered strictly to internal worker pools.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerSigningIdentity {
    /// Public UUID identifier.
    pub id: String,
    /// Target platform (`android` or `ios`).
    pub platform: String,
    /// Human-readable name.
    pub name: String,
    /// Kind of signing material.
    pub kind: String,
    /// Decrypted base64-encoded material.
    pub material: String,
    /// Parsed metadata JSON.
    pub metadata: serde_json::Value,
    /// Optional expiration timestamp.
    pub expires_at: Option<String>,
}

/// Response payload containing all decrypted signing identities for a worker job.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerSigningResponse {
    /// Collection of decrypted signing identities.
    pub identities: Vec<WorkerSigningIdentity>,
}
