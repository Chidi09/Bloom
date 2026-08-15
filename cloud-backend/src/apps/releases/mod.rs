//! The `releases` domain app: release management, approval flows, rollbacks, and multi-platform artifact grouping.

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
    approve_release, create_release, get_release, list_releases, rollback_release, update_release,
};

/// Build the releases app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
