//! Persistence models for the `builds` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// A build record represents one queued/executed build of an app within an environment.
///
/// A build is scoped to an organization (denormalized for direct multi-tenant scoping)
/// and linked to a parent `App` and `Environment` via foreign keys. Actual execution is
/// delegated to workers through the Redis job queue.
#[derive(Model, Debug, Clone)]
#[djangors(app = "builds", table_name = "builds_build")]
pub struct Build {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent application's internal primary key.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub app_id: djangors_orm::ForeignKey<crate::apps::apps::models::App>,

    /// Workflow run step waiting on this build, when one started it.
    ///
    /// `None` for a build started directly, which is most of them. When set, reaching a
    /// terminal state re-enqueues the parked parent run. Held as a plain `Option<i64>` rather
    /// than an `Option<ForeignKey<_>>` -- the derive matches on the outer type and does not
    /// compile for the latter -- so the real `ON DELETE SET NULL` lives in the migration.
    #[djangors(nullable, db_index)]
    pub workflow_run_step_id: Option<i64>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Foreign key referencing the target environment's internal primary key.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub environment_id: djangors_orm::ForeignKey<crate::apps::environments::models::Environment>,

    /// Git commit SHA to build.
    #[djangors(max_length = 40)]
    pub git_commit: String,

    /// Git branch to build.
    #[djangors(max_length = 255)]
    pub git_branch: String,

    /// Git tag or ref to build.
    #[djangors(max_length = 255)]
    pub git_ref: String,

    /// Build status: `pending`, `queued`, `running`, `success`, `failed`, or `cancelled`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// Target platform: `android`, `ios`, `web`, or `all`.
    #[djangors(max_length = 32)]
    pub platform: String,

    /// Build profile: `debug`, `profile`, or `release`.
    #[djangors(max_length = 32)]
    pub build_profile: String,

    /// Resolved Flutter SDK version.
    #[djangors(max_length = 64)]
    pub flutter_version: String,

    /// Resolved Dart SDK version.
    #[djangors(max_length = 64)]
    pub dart_version: String,

    /// Resolved Bloom CLI version.
    #[djangors(max_length = 64)]
    pub bloom_version: String,

    /// Optional build flavor.
    #[djangors(max_length = 64, nullable)]
    pub flavor: Option<String>,

    /// Timestamp when the build started running.
    #[djangors(nullable)]
    pub started_at: Option<DateTime<Utc>>,

    /// Timestamp when the build finished (success, failed, or cancelled).
    #[djangors(nullable)]
    pub finished_at: Option<DateTime<Utc>>,

    /// Optional object-storage key of the uploaded build log.
    #[djangors(max_length = 500, nullable)]
    pub logs_url: Option<String>,

    /// Optional worker identifier currently executing the build.
    #[djangors(max_length = 64, nullable)]
    pub worker_id: Option<String>,

    /// JSON text of worker-reported metadata.
    pub metadata: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Build {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A named stage of a build's execution lifecycle.
///
/// Every build records one `BuildStage` row per stage, e.g. `checkout`, `install`,
/// `resolve`, `generate`, `prebuild`, `test`, `analyze`, `build`, `upload`.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "builds",
    table_name = "builds_buildstage",
    unique_together = [["build_id", "stage"]]
)]
pub struct BuildStage {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Foreign key referencing the parent build's internal primary key.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub build_id: djangors_orm::ForeignKey<Build>,

    /// Stage name: `checkout`, `install`, `resolve`, `generate`, `prebuild`, `test`,
    /// `analyze`, `build`, or `upload`.
    #[djangors(max_length = 32)]
    pub stage: String,

    /// Stage status: `pending`, `running`, `completed`, `failed`, or `skipped`.
    #[djangors(max_length = 32)]
    pub status: String,

    /// Timestamp when the stage started running.
    #[djangors(nullable)]
    pub started_at: Option<DateTime<Utc>>,

    /// Timestamp when the stage finished.
    #[djangors(nullable)]
    pub finished_at: Option<DateTime<Utc>>,

    /// Optional tail of the stage's build log.
    #[djangors(nullable)]
    pub log_snippet: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
