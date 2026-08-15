//! HTTP contracts (request, query, and response DTOs) for the `releases` app.

use serde::{Deserialize, Serialize};

use crate::apps::artifacts::contracts::ArtifactResponse;

/// Payload to create a new release.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct ReleaseCreateRequest {
    /// Public UUID of the parent app.
    pub app_id: String,
    /// Target semantic version string (e.g. `1.0.0`).
    pub version: String,
    /// Monotonically increasing build number.
    pub build_number: i64,
    /// Git commit SHA (40 hex characters).
    pub commit: String,
    /// Optional release notes in markdown format.
    #[serde(default)]
    pub changelog: Option<String>,
    /// Optional public UUID of the target environment.
    #[serde(default)]
    pub environment_id: Option<String>,
    /// Target platforms included in this release (e.g. `["ios", "android", "web"]`).
    pub platforms: Vec<String>,
    /// Public UUIDs of artifacts to include in this release.
    pub artifact_ids: Vec<String>,
}

/// Payload to approve or reject a pending release.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct ReleaseApproveRequest {
    /// Whether the release is approved (`true`) or rejected (`false`).
    pub approved: bool,
    /// Optional rejection reason or approval comment.
    #[serde(default)]
    pub reason: Option<String>,
}

/// Optional payload for rolling back a release.
#[derive(Debug, Clone, Deserialize, Default, PartialEq, Eq)]
pub struct ReleaseRollbackRequest {
    /// Optional reason for initiating the rollback.
    #[serde(default)]
    pub reason: Option<String>,
}

/// Payload for updating an existing release.
#[derive(Debug, Clone, Deserialize, Default, PartialEq)]
pub struct ReleaseUpdateRequest {
    /// Updated changelog markdown text.
    #[serde(default)]
    pub changelog: Option<String>,
    /// Updated per-platform rollout state.
    #[serde(default)]
    pub rollout_status: Option<serde_json::Value>,
    /// Updated release status.
    #[serde(default)]
    pub status: Option<String>,
}

/// Wire representation of a release.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReleaseResponse {
    /// Public UUID identifier of the release.
    pub id: String,
    /// Public UUID identifier of the parent application.
    pub app_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Release semver version string.
    pub version: String,
    /// Integer build number.
    pub build_number: i64,
    /// Git commit SHA.
    pub commit: String,
    /// Markdown changelog text.
    pub changelog: String,
    /// Optional public UUID of the target environment.
    pub environment_id: Option<String>,
    /// Release status: `draft`, `pending_approval`, `approved`, `rolling_out`, `released`, `rolled_back`, or `expired`.
    pub status: String,
    /// Target platforms list.
    pub platforms: Vec<String>,
    /// Resolved artifact objects linked to this release.
    pub artifacts: Vec<ArtifactResponse>,
    /// Per-platform rollout status object.
    pub rollout_status: serde_json::Value,
    /// Public UUID of the creating user.
    pub created_by_id: String,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}
