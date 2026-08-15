//! Bloom webhosting domain app (Phase 4).
//!
//! Provides Flutter Web hosting, preview URLs, production deployments, custom domains,
//! deployment history, and rollback.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the webhosting app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
