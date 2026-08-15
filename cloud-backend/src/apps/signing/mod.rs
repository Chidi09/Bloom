//! Encrypted signing material storage: Android keystores, iOS certificates,
//! provisioning profiles, and App Store Connect API keys.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the signing app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
