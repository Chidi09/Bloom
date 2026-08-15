//! The `builds` domain app: build records, status transitions, stages, and logs.
//!
//! Pushes actual build execution to workers via the Redis job queue
//! (`crate::infra::queue::JobQueue`).

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the builds app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
