//! HTTP contracts (request and response DTOs) for the `builds` app.

use serde::{Deserialize, Serialize};

/// Request payload to create a new `Build` for an app/environment.
///
/// Git defaults are resolved from the app when not provided; build profile and
/// version pins are resolved from the environment when not provided.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct BuildCreateRequest {
    /// Public UUID of the parent application.
    pub app_id: String,
    /// Public UUID of the target environment.
    pub environment_id: String,
    /// Target platform: `android`, `ios`, `web`, or `all`.
    pub platform: String,
    /// Optional Git commit SHA to build (worker resolves the branch head when absent).
    #[serde(default)]
    pub git_commit: Option<String>,
    /// Optional Git branch to build (defaults to the app's default branch).
    #[serde(default)]
    pub git_branch: Option<String>,
    /// Optional Git tag or ref to build (defaults to the resolved branch).
    #[serde(default)]
    pub git_ref: Option<String>,
    /// Optional build profile (`debug`, `profile`, `release`), defaults to the environment's.
    #[serde(default)]
    pub build_profile: Option<String>,
    /// Optional pinned Flutter version, defaults to the environment's.
    #[serde(default)]
    pub flutter_version: Option<String>,
    /// Optional pinned Dart version, defaults to the environment's.
    #[serde(default)]
    pub dart_version: Option<String>,
    /// Optional pinned Bloom CLI version, defaults to the environment's.
    #[serde(default)]
    pub bloom_version: Option<String>,
    /// Optional build flavor, defaults to the environment's.
    #[serde(default)]
    pub flavor: Option<String>,
}

/// Wire representation of a single build stage.
///
/// `BuildStage` has no public UUID column, so the internal primary key is never
/// exposed; the stage is identified by its name (unique per build).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BuildStageResponse {
    /// Stage name (`checkout`, `install`, ...).
    pub stage: String,
    /// Stage status (`pending`, `running`, `completed`, `failed`, `skipped`).
    pub status: String,
    /// ISO 8601 timestamp when the stage started, if it has.
    pub started_at: Option<String>,
    /// ISO 8601 timestamp when the stage finished, if it has.
    pub finished_at: Option<String>,
    /// Optional tail of the stage's build log.
    pub log_snippet: Option<String>,
}

/// Wire representation of a `Build`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BuildResponse {
    /// Public UUID identifier of the build.
    pub id: String,
    /// Public UUID identifier of the parent application.
    pub app_id: String,
    /// Public UUID identifier of the target environment.
    pub environment_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Git commit SHA the build targeted.
    pub git_commit: String,
    /// Git branch the build targeted.
    pub git_branch: String,
    /// Git tag or ref the build targeted.
    pub git_ref: String,
    /// Build status (`pending`, `queued`, `running`, `success`, `failed`, `cancelled`).
    pub status: String,
    /// Target platform (`android`, `ios`, `web`, `all`).
    pub platform: String,
    /// Build profile (`debug`, `profile`, `release`).
    pub build_profile: String,
    /// Resolved Flutter SDK version.
    pub flutter_version: String,
    /// Resolved Dart SDK version.
    pub dart_version: String,
    /// Resolved Bloom CLI version.
    pub bloom_version: String,
    /// Build flavor, if any.
    pub flavor: Option<String>,
    /// ISO 8601 timestamp when the build started running, if it has.
    pub started_at: Option<String>,
    /// ISO 8601 timestamp when the build finished, if it has.
    pub finished_at: Option<String>,
    /// Object-storage key of the uploaded build log, if any.
    pub logs_url: Option<String>,
    /// Ordered stages of the build.
    pub stages: Vec<BuildStageResponse>,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}

/// Wire representation of the build logs endpoint.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BuildLogsResponse {
    /// Short-lived presigned download URL for the build log.
    pub url: String,
    /// Presigned URL expiry in seconds.
    pub expires_in_secs: i64,
}

/// Request payload for the internal worker stage-report endpoint.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct StageUpdateRequest {
    /// Stage name being reported (`checkout`, `install`, ...).
    pub stage: String,
    /// New stage status (`pending`, `running`, `completed`, `failed`, `skipped`).
    pub status: String,
    /// Optional tail of the stage's build log.
    #[serde(default)]
    pub log_snippet: Option<String>,
    /// Optional worker identifier claiming the job (recorded when the build starts).
    #[serde(default)]
    pub worker_id: Option<String>,
}

/// Request payload for the internal worker build-completion endpoint.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct CompleteBuildRequest {
    /// Terminal build status (`success`, `failed`, or `cancelled`).
    pub status: String,
    /// Optional worker-reported metadata as a JSON text document.
    #[serde(default)]
    pub metadata: Option<String>,
    /// Optional object-storage key of the uploaded build log.
    #[serde(default)]
    pub logs_url: Option<String>,
    /// Optional human-readable failure reason.
    #[serde(default)]
    pub reason: Option<String>,
}
