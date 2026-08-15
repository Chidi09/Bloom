//! Wire serialization adapters for the `webhosting` app.

use super::contracts::{CustomDomainResponse, WebDeploymentResponse};
use super::models::{CustomDomain, WebDeployment};

/// Safely parse JSON metadata string into `serde_json::Value`, falling back to `{}` without panicking.
pub fn parse_metadata(raw: &str) -> serde_json::Value {
    serde_json::from_str(raw).unwrap_or_else(|_| serde_json::json!({}))
}

/// Serializes a [`WebDeployment`] into its public wire representation [`WebDeploymentResponse`].
pub fn serialize_web_deployment(
    deployment: &WebDeployment,
    app_public_id: &str,
    environment_public_id: &str,
    release_public_id: Option<&str>,
    deployed_by_public_id: &str,
) -> WebDeploymentResponse {
    WebDeploymentResponse {
        id: deployment.public_id.clone(),
        app_id: app_public_id.to_string(),
        environment_id: environment_public_id.to_string(),
        release_id: release_public_id.map(|s| s.to_string()),
        target: deployment.target.clone(),
        url: deployment.url.clone(),
        status: deployment.status.clone(),
        deployed_by_id: deployed_by_public_id.to_string(),
        created_at: deployment.created_at.to_rfc3339(),
    }
}

/// Serializes a [`CustomDomain`] into its public wire representation [`CustomDomainResponse`].
pub fn serialize_custom_domain(domain: &CustomDomain, app_public_id: &str) -> CustomDomainResponse {
    CustomDomainResponse {
        id: domain.public_id.clone(),
        app_id: app_public_id.to_string(),
        domain: domain.domain.clone(),
        certificate_status: domain.certificate_status.clone(),
        certificate_expires_at: domain.certificate_expires_at.map(|t| t.to_rfc3339()),
        verified_at: domain.verified_at.map(|t| t.to_rfc3339()),
    }
}
