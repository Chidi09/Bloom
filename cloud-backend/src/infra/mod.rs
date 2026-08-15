//! Shared infrastructure layer for Bloom Cloud backend.
//!
//! Provides core cross-cutting capabilities:
//! - [`crypto`]: AES-256-GCM envelope encryption with key rotation, token hashing, and constant-time comparisons.
//! - [`storage`]: S3/R2 object storage abstraction with presigned URLs and in-memory mock backend.
//! - [`queue`]: Redis Streams-based job queue with worker claim semantics, visibility timeouts, and dead-letter handling.
//! - [`cdn`]: Cloudflare cache invalidation for web deployments.
//! - [`caddy`]: Caddy admin API client managing per-deployment site blocks.
//! - [`googleplay`]: Google Play Developer API v3 edit/upload/track/commit client.
//! - [`testflight`]: App Store Connect API client for build polling and beta group assignment.

pub mod caddy;
pub mod cdn;
pub mod crypto;
pub mod googleplay;
pub mod queue;
pub mod storage;
pub mod testflight;
