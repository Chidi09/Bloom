//! Persistence models for the `marketplace` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A publishable, versioned project template.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_template")]
pub struct Template {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the owning organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Human-readable template display name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug, unique per organization.
    #[djangors(max_length = 64)]
    pub slug: String,

    /// Optional markdown or text description.
    #[djangors(max_length = 2000, nullable)]
    pub description: Option<String>,

    /// Visibility scope: `private` (organization-only) or `public` (discoverable in marketplace).
    #[djangors(max_length = 32, default = "private", db_index)]
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    #[djangors(max_length = 32, default = "draft", db_index)]
    pub status: String,

    /// JSON metadata (tags, categories, framework requirements, icon URLs). Stored as JSON text.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Internal primary key of the user who created this template.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Template {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A specific version of a template, with manifest and file layout.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templateversion")]
pub struct TemplateVersion {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Semantic version string (e.g. `1.0.0`).
    #[djangors(max_length = 64, db_index)]
    pub version: String,

    /// Markdown changelog for this release version.
    #[djangors(default = "")]
    pub changelog: String,

    /// Template manifest (variables, dependencies, scaffold file structure). Stored as JSON text.
    #[djangors(default = "{}")]
    pub manifest: String,

    /// Markdown documentation / README for this version.
    #[djangors(default = "")]
    pub readme: String,

    /// Internal primary key of the user who published this version.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}
