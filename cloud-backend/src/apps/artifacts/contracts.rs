//! HTTP contracts (request and response DTOs) for the `artifacts` app.

use serde::{Deserialize, Serialize};

/// Payload the build worker sends to register artifact metadata after confirming the
/// upload in object storage.
///
/// `build_id` and `organization_id` are the parent build's and owning organization's
/// public UUIDs, honoring the wire contract that internal `i64` primary keys never cross
/// the API boundary.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct ArtifactRegisterRequest {
    /// Public UUID of the parent build.
    pub build_id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Target platform: `android`, `ios`, or `web`.
    pub platform: String,
    /// Artifact kind: `ipa`, `aab`, `apk`, `web_bundle`, `dsym`, `source_map`, `mapping`, or `log`.
    pub kind: String,
    /// Original uploaded file name.
    pub file_name: String,
    /// Object size in bytes.
    pub file_size: i64,
    /// SHA-256 hex digest of the artifact bytes.
    pub checksum: String,
    /// Application version this artifact was built from.
    pub version: String,
    /// Integer build number.
    pub build_number: i64,
    /// Worker-provided artifact metadata (serialized as JSON on the model).
    #[serde(default)]
    pub metadata: serde_json::Value,
    /// Name of the storage bucket holding the object.
    pub storage_bucket: String,
}

/// Wire representation of an artifact.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ArtifactResponse {
    /// Public UUID identifier of the artifact.
    pub id: String,
    /// Public UUID identifier of the parent build.
    pub build_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Target platform.
    pub platform: String,
    /// Artifact kind.
    pub kind: String,
    /// Original uploaded file name.
    pub file_name: String,
    /// Object size in bytes.
    pub file_size: i64,
    /// SHA-256 hex digest of the artifact bytes.
    pub checksum: String,
    /// Application version this artifact was built from.
    pub version: String,
    /// Integer build number.
    pub build_number: i64,
    /// Worker-provided artifact metadata.
    pub metadata: serde_json::Value,
    /// Short-lived presigned download URL; present on retrieve/download responses.
    pub download_url: Option<String>,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
}
