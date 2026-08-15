//! Persistence models for the `observability` domain app.

use chrono::{DateTime, Utc};
use djangors_macros::Model;
use djangors_orm::ForeignKey;

/// Release health snapshot recording crash rates, sessions, active users,
/// and platform raw metrics for a specific release and platform/target.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "observability",
    table_name = "observability_releasehealthsnapshot"
)]
pub struct ReleaseHealthSnapshot {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Foreign key referencing the parent release.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub release_id: ForeignKey<crate::apps::releases::models::Release>,

    /// Target platform (e.g. `ios`, `android`, `web`).
    #[djangors(max_length = 32)]
    pub platform: String,

    /// Deployment target (e.g. `testflight`, `google_play`, `production`).
    #[djangors(max_length = 32)]
    pub target: String,

    /// Computed or reported crash-free session rate in the range [0.0, 1.0].
    #[djangors(nullable)]
    pub crash_free_rate: Option<f64>,

    /// Total number of sessions observed in this snapshot period.
    #[djangors(nullable)]
    pub sessions: Option<i64>,

    /// Total number of crashes observed in this snapshot period.
    #[djangors(nullable)]
    pub crashes: Option<i64>,

    /// Total number of active users observed in this snapshot period.
    #[djangors(nullable)]
    pub active_users: Option<i64>,

    /// Raw JSON metrics payload received from vendor/platform APIs.
    #[djangors(default = "{}")]
    pub metric_data: String,

    /// Timestamp when this health snapshot was captured.
    #[djangors(auto_now_add)]
    pub captured_at: DateTime<Utc>,
}

/// Point-in-time platform metric (e.g. crash count, session count, active users)
/// associated with a deployment.
#[derive(Model, Debug, Clone)]
#[djangors(app = "observability", table_name = "observability_platformmetric")]
pub struct PlatformMetric {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Foreign key referencing the parent deployment's internal primary key.
    ///
    // TODO(spec): parallel dispatch for deployments app will supply crate::apps::deployments::models::Deployment.
    #[djangors(db_index)]
    pub deployment_id: i64,

    /// Metric type: `crash`, `session`, or `active_user`.
    #[djangors(max_length = 32)]
    pub metric_type: String,

    /// Metric measurement value.
    pub value: i64,

    /// Timestamp when this platform metric was captured.
    #[djangors(auto_now_add)]
    pub captured_at: DateTime<Utc>,
}
