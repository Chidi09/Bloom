//! Persistence models for the `projects` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// A project groups Bloom applications within an organization.
#[derive(Model, Debug, Clone)]
#[djangors(app = "projects", table_name = "projects_project")]
pub struct Project {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key pointing to `organizations_organization.id`.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: djangors_orm::ForeignKey<crate::apps::organizations::models::Organization>,

    /// Human-readable project name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug, unique per organization.
    #[djangors(max_length = 64)]
    pub slug: String,

    /// Optional project description.
    #[djangors(max_length = 1000, nullable)]
    pub description: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Project {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
