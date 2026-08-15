//! Worker layer for Bloom Cloud backend asynchronous job execution.
//!
//! # Architecture & Concurrency Model
//!
//! Workers execute long-running Flutter / Dart builds and multi-target deployments
//! claimed asynchronously from the Redis Streams job queue (`JobQueue`).
//!
//! This module provides the library-level execution logic, claim/heartbeat/ack/fail
//! state machines, and integration with storage, CDN invalidation, and Caddy reverse
//! proxy configuration:
//!
//! - [`build`]: Build worker skeleton implementing the 9-stage Flutter build lifecycle,
//!   artifact registration, build log upload, and stage event reporting.
//! - [`deploy`]: Web deployment worker uploading web bundles, invalidating Cloudflare CDN
//!   cache prefixes, and provisioning Caddy site blocks.
//!
//! # Ack/Fail Total Decision Contract
//!
//! Every claimed job must explicitly transition to either `ack` (success) or `fail`
//! (error diagnostics recorded with retry/DLQ handling). No path may return early
//! leaving an unacknowledged claim hanging until the visibility timeout.

use std::fmt;

pub mod build;
pub mod deploy;

pub use build::{run_build_job, BuildWorkerError, BuildWorkerResult};
pub use deploy::{run_deploy_job, DeployWorkerError, DeployWorkerResult};

/// Common errors across worker loop runners and job claims.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkerError {
    /// Queue interaction or claim failure.
    Queue(String),
    /// Job execution failure for a build job.
    Build(String),
    /// Job execution failure for a deploy job.
    Deploy(String),
    /// Unexpected job type for the worker.
    UnexpectedJobType(String),
}

impl fmt::Display for WorkerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            WorkerError::Queue(msg) => write!(f, "Worker queue error: {msg}"),
            WorkerError::Build(msg) => write!(f, "Build worker error: {msg}"),
            WorkerError::Deploy(msg) => write!(f, "Deploy worker error: {msg}"),
            WorkerError::UnexpectedJobType(msg) => write!(f, "Unexpected job type: {msg}"),
        }
    }
}

impl std::error::Error for WorkerError {}
