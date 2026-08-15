//! Persistence models for the `releases` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A Release is a first-class object that groups artifacts and deployment state across platforms.
///
/// A release is scoped to an organization (denormalized for direct multi-tenant scoping)
/// and linked to a parent `App` and optional target `Environment` via foreign keys.
#[derive(Model, Debug, Clone)]
#[djangors(app = "releases", table_name = "releases_release")]
pub struct Release {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent application.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub app_id: ForeignKey<crate::apps::apps::models::App>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Semver version string (e.g. `1.2.3`).
    #[djangors(max_length = 64)]
    pub version: String,

    /// Monotonically increasing integer build number.
    pub build_number: i64,

    /// Git commit SHA (up to 40 hexadecimal characters).
    #[djangors(max_length = 40)]
    pub commit: String,

    /// Release changelog in markdown format.
    #[djangors(default = "")]
    pub changelog: String,

    /// Optional foreign key referencing the target environment.
    ///
    /// A bare `Option<i64>` rather than `Option<ForeignKey<Environment>>`: the Model derive
    /// matches relations on the outer type, so a `ForeignKey` nested inside an `Option` is
    /// not recognised and fails to compile. The migration still declares the real
    /// `REFERENCES environments_environment(id) ON DELETE SET NULL` constraint, so referential
    /// integrity is enforced by the database even though the model carries no relation metadata.
    #[djangors(nullable)]
    pub environment_id: Option<i64>,

    /// Release lifecycle status: `draft`, `pending_approval`, `approved`, `rolling_out`, `released`, `rolled_back`, or `expired`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// JSON list of target platform names, e.g. `["ios", "android", "web"]`. Stored as JSON text.
    #[djangors(default = "[]")]
    pub platforms: String,

    /// JSON list of artifact public UUIDs. Stored as JSON text.
    #[djangors(default = "[]")]
    pub artifacts: String,

    /// JSON per-platform rollout state. Stored as JSON text.
    #[djangors(default = "{}")]
    pub rollout_status: String,

    /// Internal primary key of the user who created this release.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Release {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
