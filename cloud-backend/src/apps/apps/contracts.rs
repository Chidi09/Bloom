//! HTTP contracts (request and response DTOs) for the `apps` app.

use serde::{Deserialize, Serialize};

/// Request payload to create a new `App` within a project.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct AppCreateRequest {
    /// Public UUID of the parent project.
    pub project_id: String,
    /// Human-readable application name.
    pub name: String,
    /// Optional Git repository URL.
    #[serde(default)]
    pub repository_url: Option<String>,
    /// Optional default Git branch name (defaults to "main" if not provided).
    #[serde(default)]
    pub default_branch: Option<String>,
}

/// Request payload to partially update an existing `App`.
#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct AppUpdateRequest {
    /// Optional updated application name.
    pub name: Option<String>,
    /// Optional updated Git repository URL.
    pub repository_url: Option<String>,
    /// Optional updated default Git branch name.
    pub default_branch: Option<String>,
}

/// Request payload to link a local directory / project to an `App` via the CLI flow.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct AppLinkRequest {
    /// Slug of the project containing the app.
    pub project_slug: String,
    /// Slug of the target app.
    pub app_slug: String,
}

/// Wire representation of an `App`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AppResponse {
    /// Public UUID identifier of the app.
    pub id: String,
    /// Public UUID identifier of the parent project.
    pub project_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Human-readable application name.
    pub name: String,
    /// Unique URL-safe slug within the project.
    pub slug: String,
    /// Optional Git repository URL.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repository_url: Option<String>,
    /// Default Git branch name.
    pub default_branch: String,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}
