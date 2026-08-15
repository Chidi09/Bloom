//! Serialization adapters and representation converters for `releases`.

use super::contracts::ReleaseResponse;
use super::models::Release;
use crate::apps::artifacts::contracts::ArtifactResponse;

/// Safely parse a JSON string of platforms into a `Vec<String>`.
pub fn parse_platforms(raw: &str) -> Vec<String> {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Safely parse a JSON string of artifact UUIDs into a `Vec<String>`.
pub fn parse_artifact_ids(raw: &str) -> Vec<String> {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Safely parse a JSON string of rollout status into a `serde_json::Value`.
pub fn parse_rollout_status(raw: &str) -> serde_json::Value {
    serde_json::from_str(raw).unwrap_or_else(|_| serde_json::json!({}))
}

/// Serializes a [`Release`] model instance into a [`ReleaseResponse`].
///
/// `app_public_id`, `organization_public_id`, `environment_public_id`, `created_by_public_id`,
/// and `artifacts` are the external wire values corresponding to the internal foreign keys.
pub fn serialize_release(
    release: &Release,
    app_public_id: &str,
    organization_public_id: &str,
    environment_public_id: Option<&str>,
    created_by_public_id: &str,
    artifacts: Vec<ArtifactResponse>,
) -> ReleaseResponse {
    ReleaseResponse {
        id: release.public_id.clone(),
        app_id: app_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        version: release.version.clone(),
        build_number: release.build_number,
        commit: release.commit.clone(),
        changelog: release.changelog.clone(),
        environment_id: environment_public_id.map(|s| s.to_string()),
        status: release.status.clone(),
        platforms: parse_platforms(&release.platforms),
        artifacts,
        rollout_status: parse_rollout_status(&release.rollout_status),
        created_by_id: created_by_public_id.to_string(),
        created_at: release.created_at.to_rfc3339(),
        updated_at: release.updated_at.to_rfc3339(),
    }
}
