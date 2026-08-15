//! Persistence models for the `apps` domain app.

use chrono::{DateTime, Utc};
use djangors_macros::Model;

/// An application represents a Bloom application within a project.
///
/// An app is scoped to an organization (denormalized for direct multi-tenant scoping)
/// and linked to a parent `Project` via foreign key `project_id`.
#[derive(Model, Debug, Clone)]
#[djangors(app = "apps", table_name = "apps_app")]
pub struct App {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent project's internal primary key.
    #[djangors(db_index)]
    pub project_id: i64,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Human-readable application name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug unique per project.
    #[djangors(max_length = 64)]
    pub slug: String,

    /// Optional Git repository URL.
    #[djangors(max_length = 500, nullable)]
    pub repository_url: Option<String>,

    /// Default Git branch name, default "main".
    #[djangors(max_length = 255, default = "main")]
    pub default_branch: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl djangors_rest::Scoped for App {
    fn scope(
        req: &djangors_core::Request,
        qs: djangors_orm::QuerySet<Self>,
    ) -> Result<djangors_orm::QuerySet<Self>, djangors_core::DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
