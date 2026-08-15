//! Persistence models for the `webhosting` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

// The `releases` app owns `Release` and the `releases_release` table. This module
// previously carried a forward-declared duplicate of that model, registered against the
// same app label and table, while the two apps were built in parallel. Reaching the real
// model through `crate::apps::releases::models::Release` in repositories.rs replaces it.

/// A web deployment represents a published Flutter Web bundle on a preview or production URL.
///
/// Linked to parent `App`, `Environment`, and `Artifact` (web bundle) via foreign keys.
/// Scoped to an organization (denormalized for direct multi-tenant scoping).
#[derive(Model, Debug, Clone)]
#[djangors(app = "webhosting", table_name = "webhosting_webdeployment")]
pub struct WebDeployment {
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

    /// Foreign key referencing the target environment.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub environment_id: ForeignKey<crate::apps::environments::models::Environment>,

    /// Foreign key referencing the deployed web bundle artifact.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub artifact_id: ForeignKey<crate::apps::artifacts::models::Artifact>,

    /// Optional foreign key referencing an associated Release.
    ///
    /// A bare `Option<i64>` rather than `Option<ForeignKey<Release>>`: the Model derive matches
    /// relations on the outer type, so a `ForeignKey` nested inside an `Option` is not
    /// recognised and fails to compile. The migration still declares the real
    /// `REFERENCES releases_release(id) ON DELETE SET NULL` constraint.
    #[djangors(nullable)]
    pub release_id: Option<i64>,

    /// Target deployment type: `preview` or `production`.
    #[djangors(max_length = 32)]
    pub target: String,

    /// The publicly accessible deployed URL.
    #[djangors(max_length = 500)]
    pub url: String,

    /// Unique path prefix in object storage holding the web bundle assets.
    #[djangors(max_length = 500)]
    pub storage_prefix: String,

    /// Deployment lifecycle status: `deploying`, `live`, `failed`, or `rolled_back`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// JSON text holding headers, redirects, cache rules, and deployment metadata.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Internal primary key of the user who initiated the deployment.
    pub deployed_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for WebDeployment {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A custom domain associated with an app for Flutter Web hosting.
///
/// Custom domains allow mapping apex domains and subdomains to an app's production deployment.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "webhosting",
    table_name = "webhosting_customdomain",
    unique_together = [["app_id", "domain"]]
)]
pub struct CustomDomain {
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

    /// Fully qualified domain name (e.g. `app.example.com`).
    #[djangors(max_length = 255)]
    pub domain: String,

    /// TLS certificate status: `pending`, `issued`, or `expired`.
    #[djangors(max_length = 32, default = "pending")]
    pub certificate_status: String,

    /// Optional TLS certificate expiration timestamp.
    #[djangors(nullable)]
    pub certificate_expires_at: Option<DateTime<Utc>>,

    /// Optional timestamp when domain ownership was verified.
    #[djangors(nullable)]
    pub verified_at: Option<DateTime<Utc>>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for CustomDomain {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
