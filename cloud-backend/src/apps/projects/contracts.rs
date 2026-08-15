//! Request and response data contracts for the `projects` app.

use serde::{Deserialize, Serialize};

/// Payload to create a new project within an organization.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct ProjectCreateRequest {
    /// Human-readable project name.
    pub name: String,
    /// Optional project description.
    pub description: Option<String>,
}

/// Payload for partial update of a project.
#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
#[serde(default)]
pub struct ProjectUpdateRequest {
    /// Optional updated project name.
    pub name: Option<String>,
    /// Optional updated project description.
    pub description: Option<String>,
}

/// Project details serialized for API responses.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProjectResponse {
    /// Public UUID identifier.
    pub id: String,
    /// Public UUID identifier of the enclosing organization.
    pub organization_id: String,
    /// Human-readable project name.
    pub name: String,
    /// URL-safe slug unique per organization.
    pub slug: String,
    /// Optional project description.
    pub description: Option<String>,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
    /// ISO-8601 update timestamp.
    pub updated_at: String,
}
