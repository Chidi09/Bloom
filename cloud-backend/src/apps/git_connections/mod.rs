//! Git provider OAuth/app connections and webhook handling.
//!
//! Provides connection management for GitHub, GitLab, and Bitbucket,
//! repository listing, and secure HMAC-SHA256 signature-verified,
//! idempotent webhook processing.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

/// Build and return the `git_connections` app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
