//! Persistence models for the `deployments` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A Deployment is a single push of an artifact/release to a platform target (TestFlight, Google Play track, web production, etc.).
///
/// Scoped to an organization (denormalized for direct multi-tenant scoping) and linked to
/// an `Environment` via a required foreign key, with optional nullable foreign keys to `Release` and `Artifact`.
#[derive(Model, Debug, Clone)]
#[djangors(app = "deployments", table_name = "deployments_deployment")]
pub struct Deployment {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Optional foreign key referencing an associated Release.
    ///
    /// Declared as `Option<i64>` rather than `Option<ForeignKey<Release>>` because the Model derive
    /// matches relations on the outer type, so a `ForeignKey` nested inside an `Option` is not
    /// recognized. The database migration enforces `REFERENCES releases_release(id) ON DELETE SET NULL`.
    #[djangors(nullable, db_index)]
    pub release_id: Option<i64>,

    /// Optional foreign key referencing an associated Artifact.
    ///
    /// Declared as `Option<i64>` rather than `Option<ForeignKey<Artifact>>` because the Model derive
    /// matches relations on the outer type, so a `ForeignKey` nested inside an `Option` is not
    /// recognized. The database migration enforces `REFERENCES artifacts_artifact(id) ON DELETE SET NULL`.
    #[djangors(nullable)]
    pub artifact_id: Option<i64>,

    /// Foreign key referencing the target environment.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub environment_id: ForeignKey<crate::apps::environments::models::Environment>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Target platform: `ios`, `android`, or `web`.
    #[djangors(max_length = 32)]
    pub platform: String,

    /// Target platform destination: `testflight`, `app_store`, `internal`, `closed`, `open`, `production`, or `preview`.
    #[djangors(max_length = 32)]
    pub target: String,

    /// Deployment lifecycle status: `pending`, `queued`, `running`, `processing`, `ready`, `live`, `failed`, or `rolled_back`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// Platform-specific identifier returned by the provider (e.g. TestFlight build ID, Play track release ID).
    #[djangors(max_length = 255, nullable)]
    pub external_id: Option<String>,

    /// Direct web console URL for the deployment on the target platform.
    #[djangors(max_length = 500, nullable)]
    pub external_url: Option<String>,

    /// Platform or worker failure diagnostics when deployment fails.
    #[djangors(nullable)]
    pub error_message: Option<String>,

    /// Timestamp when deployment execution began.
    #[djangors(nullable)]
    pub started_at: Option<DateTime<Utc>>,

    /// Timestamp when deployment reached a terminal or completed state.
    #[djangors(nullable)]
    pub finished_at: Option<DateTime<Utc>>,

    /// Internal primary key of the user who initiated the deployment.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Deployment {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
