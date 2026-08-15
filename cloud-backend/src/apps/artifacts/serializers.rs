//! Serializers and representation converters for the `artifacts` app.

use super::contracts::ArtifactResponse;
use super::models::Artifact;

/// Serializes an `Artifact` model instance into an `ArtifactResponse` wire contract.
///
/// `build_public_id` and `organization_public_id` are the external UUID strings
/// corresponding to the foreign keys on the model. `download_url` carries a short-lived
/// presigned URL when available (retrieve/download responses), or `None` for list responses.
pub fn serialize_artifact(
    artifact: &Artifact,
    build_public_id: &str,
    organization_public_id: &str,
    download_url: Option<String>,
) -> ArtifactResponse {
    let metadata = serde_json::from_str(&artifact.metadata).unwrap_or_default();

    ArtifactResponse {
        id: artifact.public_id.clone(),
        build_id: build_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        platform: artifact.platform.clone(),
        kind: artifact.kind.clone(),
        file_name: artifact.file_name.clone(),
        file_size: artifact.file_size,
        checksum: artifact.checksum.clone(),
        version: artifact.version.clone(),
        build_number: artifact.build_number,
        metadata,
        download_url,
        created_at: artifact.created_at.to_rfc3339(),
    }
}
