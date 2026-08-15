//! Persistence models for the `environments` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// An environment holds configuration, secrets, build defaults, and deployment targets for an app.
/// Common: `development`, `staging`, `production`.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "environments",
    table_name = "environments_environment",
    unique_together = [["app_id", "slug"]]
)]
pub struct Environment {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent app's internal primary key.
    #[djangors(db_index)]
    pub app_id: i64,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Human-readable environment name (e.g. `production`).
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug unique per app (e.g. `prod`, `staging`).
    #[djangors(max_length = 64)]
    pub slug: String,

    /// JSON text storing non-secret environment variables and feature flags.
    pub api_config: String,

    /// Default build profile: `debug`, `profile`, `release`.
    #[djangors(max_length = 32, default = "release")]
    pub build_profile: String,

    /// Optional pinned Flutter version.
    #[djangors(max_length = 64, nullable)]
    pub flutter_version: Option<String>,

    /// Optional pinned Dart version.
    #[djangors(max_length = 64, nullable)]
    pub dart_version: Option<String>,

    /// Optional pinned Bloom CLI version.
    #[djangors(max_length = 64, nullable)]
    pub bloom_version: Option<String>,

    /// Optional build flavor.
    #[djangors(max_length = 64, nullable)]
    pub flavor: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Environment {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
