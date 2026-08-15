//! Request and response Data Transfer Objects (DTOs) for `webhosting`.

use serde::{Deserialize, Serialize};

/// Wire response representation for a [`crate::apps::webhosting::models::WebDeployment`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebDeploymentResponse {
    /// External public UUID of the deployment.
    pub id: String,
    /// External public UUID of the parent app.
    pub app_id: String,
    /// External public UUID of the target environment.
    pub environment_id: String,
    /// Optional external public UUID of the associated release.
    pub release_id: Option<String>,
    /// Target type: `preview` or `production`.
    pub target: String,
    /// The public URL where the web app is deployed.
    pub url: String,
    /// Deployment status: `deploying`, `live`, `failed`, or `rolled_back`.
    pub status: String,
    /// External public UUID or identifier string of the user who deployed.
    pub deployed_by_id: String,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Wire response representation for a [`crate::apps::webhosting::models::CustomDomain`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomDomainResponse {
    /// External public UUID of the custom domain.
    pub id: String,
    /// External public UUID of the parent app.
    pub app_id: String,
    /// Fully qualified domain name.
    pub domain: String,
    /// TLS certificate status: `pending`, `issued`, or `expired`.
    pub certificate_status: String,
    /// Optional ISO-8601 certificate expiration timestamp.
    pub certificate_expires_at: Option<String>,
    /// Optional ISO-8601 verification timestamp.
    pub verified_at: Option<String>,
}

/// Request body for initiating a new web deployment.
#[derive(Debug, Clone, Deserialize)]
pub struct DeployWebRequest {
    /// External public UUID of the app to deploy.
    pub app_id: String,
    /// External public UUID of the target environment.
    pub environment_id: String,
    /// External public UUID of the web bundle artifact to deploy.
    pub artifact_id: String,
    /// Optional external public UUID of a release to link with this deployment.
    #[serde(default)]
    pub release_id: Option<String>,
    /// Target environment type: `preview` or `production`.
    pub target: String,
    /// Git branch name used for preview URL slug generation (defaults to app's default branch).
    #[serde(default)]
    pub git_branch: Option<String>,
    /// Optional custom metadata (headers, redirects, caching rules).
    #[serde(default)]
    pub metadata: Option<serde_json::Value>,
}

/// Request body for registering a custom domain.
#[derive(Debug, Clone, Deserialize)]
pub struct CreateCustomDomainRequest {
    /// External public UUID of the app.
    pub app_id: String,
    /// Domain name to register (e.g. `app.example.com`).
    pub domain: String,
}
