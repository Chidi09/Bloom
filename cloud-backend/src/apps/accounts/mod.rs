//! Identity, authentication, profile, and API token domain app.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use permissions::CurrentOrganizationId;

/// Build the accounts app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
