//! The `marketplace` domain app: Bloom templates, versioning, marketplace public catalog, and organization-scoped template management.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use services::{
    archive_template, create_template, create_template_version, delete_template,
    delete_template_version, get_org_template, get_public_template, get_public_template_version,
    get_template_version, list_org_templates, list_public_templates, list_template_versions,
    publish_template, update_template,
};

/// Build the marketplace app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
