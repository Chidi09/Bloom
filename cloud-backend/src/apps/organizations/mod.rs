//! Tenancy, membership, role authorization, and organization management.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the organizations app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
