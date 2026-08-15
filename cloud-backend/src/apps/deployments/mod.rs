//! Bloom deployments domain app (Phase 5).
//!
//! Provides platform deployments (iOS TestFlight, Android Google Play tracks, Web CDN),
//! status transitions, approval gating for production, and rollback capabilities.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the deployments app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
