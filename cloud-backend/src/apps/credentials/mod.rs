//! Platform API credentials vault: Apple App Store Connect, Google Play,
//! Shorebird, GitHub, GitLab, Bitbucket.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build the credentials app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
