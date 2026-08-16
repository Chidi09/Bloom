//! Wire serialization adapters for the `deployments` app.

use super::contracts::DeploymentResponse;
use super::models::Deployment;

/// Serializes a [`Deployment`] into its public wire representation [`DeploymentResponse`].
pub fn serialize_deployment(
    deployment: &Deployment,
    release_public_id: Option<&str>,
    artifact_public_id: Option<&str>,
    environment_public_id: &str,
    organization_public_id: &str,
    created_by_public_id: &str,
) -> DeploymentResponse {
    DeploymentResponse {
        id: deployment.public_id.clone(),
        release_id: release_public_id.map(|s| s.to_string()),
        artifact_id: artifact_public_id.map(|s| s.to_string()),
        environment_id: environment_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        platform: deployment.platform.clone(),
        target: deployment.target.clone(),
        status: deployment.status.clone(),
        external_id: deployment.external_id.clone(),
        external_url: deployment.external_url.clone(),
        preview_image_url: deployment.preview_image_url.clone(),
        error_message: deployment.error_message.clone(),
        started_at: deployment.started_at.map(|t| t.to_rfc3339()),
        finished_at: deployment.finished_at.map(|t| t.to_rfc3339()),
        created_by_id: created_by_public_id.to_string(),
        created_at: deployment.created_at.to_rfc3339(),
        updated_at: deployment.updated_at.to_rfc3339(),
    }
}
