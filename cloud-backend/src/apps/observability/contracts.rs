//! Request and response data contracts for the `observability` domain app.

use serde::{Deserialize, Serialize};

/// Aggregated health status response for a release across all target platforms.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReleaseHealthResponse {
    /// Public UUID of the release.
    pub release_id: String,

    /// Overall crash-free rate across all platforms (0.0 to 1.0), or `None` if no session data.
    pub overall_crash_free_rate: Option<f64>,

    /// Per-platform health summaries.
    pub platforms: Vec<PlatformHealth>,
}

/// Platform-specific health metrics and status summary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PlatformHealth {
    /// Platform name (e.g. `ios`, `android`, `web`).
    pub platform: String,

    /// Deployment target (e.g. `testflight`, `google_play`, `production`).
    pub target: String,

    /// Computed or reported crash-free rate (0.0 to 1.0), or `None` if no session data.
    pub crash_free_rate: Option<f64>,

    /// Number of sessions recorded, if available.
    pub sessions: Option<i64>,

    /// Number of crashes recorded, if available.
    pub crashes: Option<i64>,

    /// Platform health status: `healthy`, `warning`, `degraded`, or `unknown`.
    pub status: String,
}

/// Overall live deployment and health status for an application across environments.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AppStatusResponse {
    /// Public UUID of the application.
    pub app_id: String,

    /// Per-environment live release and health statuses.
    pub environments: Vec<EnvironmentStatus>,
}

/// Status and health details for an application within a specific environment and platform.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnvironmentStatus {
    /// Environment slug or name (e.g. `production`, `staging`).
    pub environment: String,

    /// Platform name (e.g. `ios`, `android`, `web`).
    pub platform: String,

    /// Public UUID of the current live release, if any.
    pub release_id: Option<String>,

    /// Version string of the current release (e.g. `1.0.0`), if any.
    pub version: Option<String>,

    /// Build number of the current release, if any.
    pub build_number: Option<i64>,

    /// Release status in this environment (e.g. `released`, `rolling_out`, `healthy`, `no_release`).
    pub status: String,

    /// Overall crash-free rate for this release in this environment, if available.
    pub crash_free_rate: Option<f64>,
}

/// Input payload for capturing a new release health snapshot.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CaptureSnapshotRequest {
    /// Public UUID of the release.
    pub release_id: String,

    /// Platform name (e.g. `ios`, `android`, `web`).
    pub platform: String,

    /// Deployment target (e.g. `testflight`, `google_play`, `production`).
    pub target: String,

    /// Optional crash-free session rate in range [0.0, 1.0].
    pub crash_free_rate: Option<f64>,

    /// Optional total session count.
    pub sessions: Option<i64>,

    /// Optional total crash count.
    pub crashes: Option<i64>,

    /// Optional active user count.
    pub active_users: Option<i64>,

    /// Optional raw vendor/platform metric JSON payload.
    pub metric_data: Option<serde_json::Value>,
}

/// Input payload for recording a point-in-time platform metric.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RecordPlatformMetricRequest {
    /// Internal or external deployment identifier.
    pub deployment_id: i64,

    /// Metric type: `crash`, `session`, or `active_user`.
    pub metric_type: String,

    /// Metric numeric value.
    pub value: i64,
}
