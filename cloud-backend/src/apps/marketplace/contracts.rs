//! Data Transfer Objects (DTOs) and wire contracts for the `marketplace` app.

use serde::{Deserialize, Serialize};

/// Inbound payload for creating a new project template.
#[derive(Debug, Clone, Deserialize)]
pub struct TemplateCreateRequest {
    /// Human-readable template display name.
    pub name: String,

    /// Optional markdown or text description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public` (defaults to `private`).
    pub visibility: Option<String>,

    /// Optional structured JSON metadata (framework version, tags, platforms).
    pub metadata: Option<serde_json::Value>,
}

/// Inbound partial payload for updating an existing project template.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct TemplateUpdateRequest {
    /// Optional updated display name.
    pub name: Option<String>,

    /// Optional updated description.
    pub description: Option<String>,

    /// Optional updated visibility (`private` or `public`).
    pub visibility: Option<String>,

    /// Optional updated lifecycle status (`draft`, `published`, `archived`).
    pub status: Option<String>,

    /// Optional updated structured JSON metadata.
    pub metadata: Option<serde_json::Value>,
}

/// Inbound payload for explicitly publishing a template.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct TemplatePublishRequest {
    /// Optional updated visibility on publish (e.g. promote to `public`).
    pub visibility: Option<String>,
}

/// Inbound payload for creating and publishing a new template version.
#[derive(Debug, Clone, Deserialize)]
pub struct TemplateVersionCreateRequest {
    /// Semantic version string (e.g. `1.0.0`).
    pub version: String,

    /// Optional markdown release notes / changelog for this version.
    pub changelog: Option<String>,

    /// Optional structured template manifest (scaffold structure, variables).
    pub manifest: Option<serde_json::Value>,

    /// Optional markdown documentation / README.
    pub readme: Option<String>,
}

/// Outbound wire representation of a project template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the owning organization.
    pub organization_id: String,

    /// Display name.
    pub name: String,

    /// URL-safe slug unique per organization.
    pub slug: String,

    /// Optional description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public`.
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    pub status: String,

    /// Parsed JSON metadata.
    pub metadata: serde_json::Value,

    /// Semver string of the latest available version, if any.
    pub latest_version: Option<String>,

    /// Total count of published versions for this template.
    pub versions_count: i64,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Outbound detailed representation of a template including all version summaries.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateDetailResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the owning organization.
    pub organization_id: String,

    /// Display name.
    pub name: String,

    /// URL-safe slug unique per organization.
    pub slug: String,

    /// Optional description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public`.
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    pub status: String,

    /// Parsed JSON metadata.
    pub metadata: serde_json::Value,

    /// Summary list of all available versions.
    pub versions: Vec<TemplateVersionSummaryResponse>,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Outbound wire representation of a full template version.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVersionResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the parent template.
    pub template_id: String,

    /// Semantic version string.
    pub version: String,

    /// Markdown changelog.
    pub changelog: String,

    /// Parsed JSON manifest (variables, file structures).
    pub manifest: serde_json::Value,

    /// Markdown documentation / README.
    pub readme: String,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Lightweight summary of a template version in listing contexts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVersionSummaryResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// Semantic version string.
    pub version: String,

    /// Markdown changelog.
    pub changelog: String,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,
}
