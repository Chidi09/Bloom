//! Request and response Data Transfer Objects (DTOs) for `deployments`.

use serde::{Deserialize, Serialize};

/// Request body for creating a new deployment.
#[derive(Debug, Clone, Deserialize)]
pub struct DeploymentCreateRequest {
    /// Optional external public UUID of an associated Release.
    #[serde(default)]
    pub release_id: Option<String>,
    /// Optional external public UUID of an associated Artifact.
    #[serde(default)]
    pub artifact_id: Option<String>,
    /// External public UUID of the target environment.
    pub environment_id: String,
    /// Target platform: `ios`, `android`, or `web`.
    pub platform: String,
    /// Target platform destination (e.g. `testflight`, `app_store`, `internal`, `closed`, `open`, `production`, `preview`).
    pub target: String,
}

/// Wire response representation for a [`crate::apps::deployments::models::Deployment`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeploymentResponse {
    /// External public UUID of the deployment.
    pub id: String,
    /// Optional external public UUID of the associated Release.
    pub release_id: Option<String>,
    /// Optional external public UUID of the associated Artifact.
    pub artifact_id: Option<String>,
    /// External public UUID of the target environment.
    pub environment_id: String,
    /// External public UUID of the tenant organization.
    pub organization_id: String,
    /// Target platform: `ios`, `android`, or `web`.
    pub platform: String,
    /// Target destination.
    pub target: String,
    /// Lifecycle status: `pending`, `queued`, `running`, `processing`, `ready`, `live`, `failed`, or `rolled_back`.
    pub status: String,
    /// Platform-specific identifier returned by the provider.
    pub external_id: Option<String>,
    /// Platform console URL.
    pub external_url: Option<String>,
    /// Platform or worker failure diagnostics.
    pub error_message: Option<String>,
    /// ISO-8601 timestamp when deployment execution began.
    pub started_at: Option<String>,
    /// ISO-8601 timestamp when deployment completed or failed.
    pub finished_at: Option<String>,
    /// External public UUID of the user who initiated the deployment.
    pub created_by_id: String,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
    /// ISO-8601 last update timestamp.
    pub updated_at: String,
}
