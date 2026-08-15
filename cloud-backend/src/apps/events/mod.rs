//! Event log: durable storage, read-only API, and the public event-recording
//! service interface that every other Bloom Cloud app uses to emit events.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use services::{emit, record_event};

/// Build the events app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
