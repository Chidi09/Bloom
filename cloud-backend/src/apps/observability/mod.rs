//! Observability domain app: platform-reported metrics storage, release health aggregation,
//! and application health dashboard endpoints.

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
    capture_health_snapshot, get_app_status, get_release_health, record_platform_metric,
};

/// Build and return the observability app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
