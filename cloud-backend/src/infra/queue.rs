//! Redis Streams-based job queue for build and deployment workers.
//!
//! # Architecture & Concurrency Model
//!
//! Build and deployment jobs require isolated worker containers, ephemeral tokens,
//! and artifact lifecycles.
//!
//! This module provides a Redis Streams backed queue with **exclusive claim semantics**
//! equivalent to `SELECT ... FOR UPDATE SKIP LOCKED`:
//!
//! - **Single Worker Claim**: A job is claimed by at most one worker.
//! - **Visibility Timeout & Auto-Reclaim**: If a worker crashes or becomes unresponsive without
//!   heartbeating within `worker_claim_timeout_secs` (default 30s, configured via `BloomSettings`),
//!   the job automatically becomes available for other workers to claim.
//! - **Dead-Letter Queue (DLQ)**: After `max_retries` attempts (default 3), repeatedly failing
//!   jobs are transferred to `bloomcloud:jobs:dead_letter` along with failure diagnostics.
//! - **Heartbeating**: Long-running jobs extend their claim timeout via periodic heartbeats.

use std::collections::{HashMap, VecDeque};
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

/// Default Redis stream key for pending jobs.
pub const DEFAULT_STREAM_KEY: &str = "bloomcloud:jobs";

/// Default Redis dead-letter stream key for jobs exceeding retry limits.
pub const DEFAULT_DEAD_LETTER_STREAM_KEY: &str = "bloomcloud:jobs:dead_letter";

/// Default consumer group for worker nodes.
pub const DEFAULT_CONSUMER_GROUP: &str = "workers";

/// Default visibility claim timeout in seconds (30 seconds).
pub const DEFAULT_CLAIM_TIMEOUT_SECS: u64 = 30;

/// Default maximum retry attempts before dead-lettering.
pub const DEFAULT_MAX_RETRIES: u32 = 3;

/// Errors arising from job queue operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QueueError {
    /// Error interacting with the Redis backend.
    Redis(String),
    /// Error serializing or deserializing a job payload.
    Serialization(String),
    /// Job ID not found in stream or pending entries.
    JobNotFound(String),
    /// Job exceeded maximum retry attempts.
    MaxRetriesExceeded(String),
    /// Stream entry payload is malformed or missing required fields.
    InvalidPayload(String),
    /// Redis connection or network error.
    Connection(String),
}

impl fmt::Display for QueueError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            QueueError::Redis(msg) => write!(f, "Redis queue error: {msg}"),
            QueueError::Serialization(msg) => write!(f, "Queue serialization error: {msg}"),
            QueueError::JobNotFound(id) => write!(f, "Job not found in queue: {id}"),
            QueueError::MaxRetriesExceeded(msg) => write!(f, "Job exceeded retry limit: {msg}"),
            QueueError::InvalidPayload(msg) => write!(f, "Invalid job payload in stream: {msg}"),
            QueueError::Connection(msg) => write!(f, "Redis connection failed: {msg}"),
        }
    }
}

impl std::error::Error for QueueError {}

/// Typed job payload representing asynchronous work for workers.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "job_type")]
pub enum Job {
    /// Flutter / Dart build job execution.
    Build {
        /// Public UUID of the build record.
        build_id: String,
        /// Public UUID of the owning organization.
        organization_id: String,
        /// Public UUID of the project.
        project_id: String,
        /// Public UUID of the application.
        app_id: String,
        /// Public UUID of the environment.
        environment_id: String,
        /// Git commit SHA to check out.
        git_commit: String,
        /// Target platform: `android`, `ios`, or `web`.
        platform: String,
        /// Build profile: `debug`, `profile`, or `release`.
        build_profile: String,
    },
    /// Platform deployment job (TestFlight, Google Play, Web CDN).
    Deploy {
        /// Public UUID of the deployment record.
        deployment_id: String,
        /// Public UUID of the organization.
        organization_id: String,
        /// Public UUID of the associated release (if any).
        release_id: Option<String>,
        /// Public UUID of the artifact being deployed.
        artifact_id: String,
        /// Target platform: `ios`, `android`, or `web`.
        platform: String,
        /// Platform target (e.g. `testflight`, `production`, `internal`, `closed`).
        target: String,
    },
    /// Asynchronous webhook processing job.
    Webhook {
        /// Unique webhook delivery ID.
        delivery_id: String,
        /// Provider name (e.g. `github`, `gitlab`, `bitbucket`).
        provider: String,
        /// Raw webhook JSON payload.
        payload: serde_json::Value,
        /// Cryptographic HMAC signature from provider.
        signature: String,
    },
    /// Workflow run execution job, claimed by the workflow worker.
    ///
    /// A workflow run is re-enqueued as this same variant each time it resumes -- after an
    /// approval gate is granted, or after a child build or deploy reaches a terminal state --
    /// so a resuming run is indistinguishable from a fresh one to the queue.
    Workflow {
        /// Public UUID of the workflow run.
        run_id: String,
        /// Public UUID of the owning organization.
        organization_id: String,
        /// Public UUID of the parent workflow definition.
        workflow_id: String,
        /// Public UUID of the target environment, when the run is scoped to one.
        environment_id: Option<String>,
    },
}

impl Job {
    /// Returns the unique public identifier associated with the job.
    pub fn id(&self) -> &str {
        match self {
            Job::Build { build_id, .. } => build_id,
            Job::Deploy { deployment_id, .. } => deployment_id,
            Job::Webhook { delivery_id, .. } => delivery_id,
            Job::Workflow { run_id, .. } => run_id,
        }
    }

    /// Returns the discriminator string tag of the job.
    pub fn job_type(&self) -> &'static str {
        match self {
            Job::Build { .. } => "Build",
            Job::Deploy { .. } => "Deploy",
            Job::Webhook { .. } => "Webhook",
            Job::Workflow { .. } => "Workflow",
        }
    }
}

/// Metadata envelope wrapping a queued or claimed job.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct QueuedJob {
    /// Stream message identifier (e.g., Redis stream ID `1691234567890-0`).
    pub stream_id: String,
    /// The inner typed job payload.
    pub job: Job,
    /// Number of times this job has been attempted.
    pub retry_count: u32,
    /// Maximum allowed attempts before sending to DLQ.
    pub max_retries: u32,
    /// Timestamp when the job was initially enqueued.
    pub created_at: DateTime<Utc>,
    /// Timestamp when the job was claimed by the current worker.
    pub claimed_at: Option<DateTime<Utc>>,
    /// Name of the consumer/worker currently holding the claim.
    pub claimed_by: Option<String>,
    /// Last error diagnostic recorded during previous attempt.
    pub last_error: Option<String>,
}

/// Production Redis Streams-backed job queue.
#[derive(Clone)]
pub struct JobQueue {
    redis: redis::Client,
    stream_key: String,
    dead_letter_stream_key: String,
    consumer_group: String,
    claim_timeout_secs: u64,
    max_retries: u32,
}

impl JobQueue {
    /// Creates a new `JobQueue` client with default configurations.
    pub fn new(redis: redis::Client) -> Self {
        Self {
            redis,
            stream_key: DEFAULT_STREAM_KEY.to_string(),
            dead_letter_stream_key: DEFAULT_DEAD_LETTER_STREAM_KEY.to_string(),
            consumer_group: DEFAULT_CONSUMER_GROUP.to_string(),
            claim_timeout_secs: DEFAULT_CLAIM_TIMEOUT_SECS,
            max_retries: DEFAULT_MAX_RETRIES,
        }
    }

    /// Connects to Redis using a connection URL string.
    pub fn from_url(redis_url: &str) -> Result<Self, QueueError> {
        let client =
            redis::Client::open(redis_url).map_err(|e| QueueError::Connection(e.to_string()))?;
        Ok(Self::new(client))
    }

    /// Sets the Redis stream key.
    pub fn with_stream_key(mut self, stream_key: impl Into<String>) -> Self {
        self.stream_key = stream_key.into();
        self
    }

    /// Sets the Redis dead-letter stream key.
    pub fn with_dead_letter_stream_key(mut self, dlq_key: impl Into<String>) -> Self {
        self.dead_letter_stream_key = dlq_key.into();
        self
    }

    /// Sets the consumer group name.
    pub fn with_consumer_group(mut self, consumer_group: impl Into<String>) -> Self {
        self.consumer_group = consumer_group.into();
        self
    }

    /// Sets the worker claim visibility timeout in seconds.
    pub fn with_claim_timeout_secs(mut self, timeout_secs: u64) -> Self {
        self.claim_timeout_secs = timeout_secs;
        self
    }

    /// Sets the maximum retry limit before moving to dead-letter queue.
    pub fn with_max_retries(mut self, max_retries: u32) -> Self {
        self.max_retries = max_retries;
        self
    }

    /// Helper to obtain an asynchronous multiplexed Redis connection.
    async fn conn(&self) -> Result<redis::aio::MultiplexedConnection, QueueError> {
        self.redis
            .get_multiplexed_async_connection()
            .await
            .map_err(|e| QueueError::Connection(e.to_string()))
    }

    /// Ensures that the Redis consumer group and stream exist.
    /// Verifies Redis is reachable by issuing `PING`.
    ///
    /// Used by the `/readyz` readiness probe. Returns `Ok(())` only when Redis
    /// answers, so a readiness check fails closed if the broker is unreachable.
    pub async fn ping(&self) -> Result<(), QueueError> {
        let mut conn = self.conn().await?;
        redis::cmd("PING")
            .query_async::<String>(&mut conn)
            .await
            .map(|_| ())
            .map_err(|e| QueueError::Redis(e.to_string()))
    }

    pub async fn ensure_group(&self) -> Result<(), QueueError> {
        let mut conn = self.conn().await?;
        // XGROUP CREATE stream_key consumer_group 0 MKSTREAM
        let res: redis::RedisResult<()> = redis::cmd("XGROUP")
            .arg("CREATE")
            .arg(&self.stream_key)
            .arg(&self.consumer_group)
            .arg("0")
            .arg("MKSTREAM")
            .query_async(&mut conn)
            .await;

        match res {
            Ok(()) => Ok(()),
            Err(e) => {
                let msg = e.to_string();
                if msg.contains("BUSYGROUP") {
                    Ok(()) // Consumer group already exists
                } else {
                    Err(QueueError::Redis(msg))
                }
            }
        }
    }

    /// Enqueues a new job to the stream.
    pub async fn push(&self, job: Job) -> Result<String, QueueError> {
        self.push_envelope(job, 0, self.max_retries, None).await
    }

    /// Enqueues a job with a custom max retry limit.
    pub async fn push_with_retry_limit(
        &self,
        job: Job,
        max_retries: u32,
    ) -> Result<String, QueueError> {
        self.push_envelope(job, 0, max_retries, None).await
    }

    /// Internal helper to push a job with metadata fields to Redis Streams.
    async fn push_envelope(
        &self,
        job: Job,
        retry_count: u32,
        max_retries: u32,
        last_error: Option<String>,
    ) -> Result<String, QueueError> {
        let mut conn = self.conn().await?;
        let job_json =
            serde_json::to_string(&job).map_err(|e| QueueError::Serialization(e.to_string()))?;

        let created_at_str = Utc::now().to_rfc3339();
        let retry_count_str = retry_count.to_string();
        let max_retries_str = max_retries.to_string();
        let error_str = last_error.unwrap_or_default();

        let stream_id: String = redis::cmd("XADD")
            .arg(&self.stream_key)
            .arg("*")
            .arg("job_payload")
            .arg(&job_json)
            .arg("retry_count")
            .arg(&retry_count_str)
            .arg("max_retries")
            .arg(&max_retries_str)
            .arg("created_at")
            .arg(&created_at_str)
            .arg("last_error")
            .arg(&error_str)
            .query_async(&mut conn)
            .await
            .map_err(|e| QueueError::Redis(e.to_string()))?;

        Ok(stream_id)
    }

    /// Claims a pending or stale job for the specified worker consumer.
    ///
    /// Implements `SELECT ... FOR UPDATE SKIP LOCKED` equivalent semantics:
    /// 1. First checks for abandoned claims via `XAUTOCLAIM` with `claim_timeout_secs`.
    /// 2. If no abandoned jobs exist, claims new incoming entries using `XREADGROUP`.
    pub async fn claim(&self, consumer_name: &str) -> Result<Option<QueuedJob>, QueueError> {
        self.ensure_group().await?;
        let mut conn = self.conn().await?;

        // 1. Try to recover timed-out / abandoned job from dead workers via XAUTOCLAIM
        let min_idle_time_ms = self.claim_timeout_secs * 1000;
        let autoclaim_res: redis::RedisResult<redis::Value> = redis::cmd("XAUTOCLAIM")
            .arg(&self.stream_key)
            .arg(&self.consumer_group)
            .arg(consumer_name)
            .arg(min_idle_time_ms)
            .arg("0-0")
            .arg("COUNT")
            .arg(1)
            .query_async(&mut conn)
            .await;

        if let Ok(redis::Value::Array(ref items)) = autoclaim_res {
            if items.len() >= 2 {
                if let redis::Value::Array(ref messages) = items[1] {
                    if let Some(msg) = messages.first() {
                        if let Some(job) = parse_stream_entry(msg, consumer_name)? {
                            return Ok(Some(job));
                        }
                    }
                }
            }
        }

        // 2. Read new unassigned pending job via XREADGROUP
        let read_res: redis::RedisResult<redis::Value> = redis::cmd("XREADGROUP")
            .arg("GROUP")
            .arg(&self.consumer_group)
            .arg(consumer_name)
            .arg("BLOCK")
            .arg(100) // Block 100ms
            .arg("COUNT")
            .arg(1)
            .arg("STREAMS")
            .arg(&self.stream_key)
            .arg(">")
            .query_async(&mut conn)
            .await;

        match read_res {
            Ok(redis::Value::Array(streams)) => {
                for stream in streams {
                    if let redis::Value::Array(stream_items) = stream {
                        if stream_items.len() >= 2 {
                            if let redis::Value::Array(messages) = &stream_items[1] {
                                if let Some(msg) = messages.first() {
                                    if let Some(job) = parse_stream_entry(msg, consumer_name)? {
                                        return Ok(Some(job));
                                    }
                                }
                            }
                        }
                    }
                }
                Ok(None)
            }
            Ok(_) => Ok(None),
            Err(e) => Err(QueueError::Redis(e.to_string())),
        }
    }

    /// Extends the visibility timeout / claim of an in-flight job by heartbeating.
    pub async fn heartbeat(
        &self,
        job_stream_id: &str,
        consumer_name: &str,
    ) -> Result<(), QueueError> {
        let mut conn = self.conn().await?;
        // Re-claim the stream ID with XCLAIM to reset the idle timer in the PEL (Pending Entries List)
        let _: redis::Value = redis::cmd("XCLAIM")
            .arg(&self.stream_key)
            .arg(&self.consumer_group)
            .arg(consumer_name)
            .arg(0) // 0ms idle time to force ownership and reset idle timer
            .arg(job_stream_id)
            .query_async(&mut conn)
            .await
            .map_err(|e| QueueError::Redis(e.to_string()))?;

        Ok(())
    }

    /// Acknowledges and deletes a successfully completed job from the stream.
    pub async fn ack(&self, job_stream_id: &str) -> Result<(), QueueError> {
        let mut conn = self.conn().await?;

        // 1. Acknowledge message in consumer group
        let _: i64 = redis::cmd("XACK")
            .arg(&self.stream_key)
            .arg(&self.consumer_group)
            .arg(job_stream_id)
            .query_async(&mut conn)
            .await
            .map_err(|e| QueueError::Redis(e.to_string()))?;

        // 2. Delete message from stream
        let _: i64 = redis::cmd("XDEL")
            .arg(&self.stream_key)
            .arg(job_stream_id)
            .query_async(&mut conn)
            .await
            .map_err(|e| QueueError::Redis(e.to_string()))?;

        Ok(())
    }

    /// Handles a failed job: retries if below max retry count; moves to DLQ if exceeded.
    pub async fn fail(&self, job_stream_id: &str, reason: &str) -> Result<(), QueueError> {
        let mut conn = self.conn().await?;

        // 1. Fetch existing message data
        let range_res: redis::RedisResult<redis::Value> = redis::cmd("XRANGE")
            .arg(&self.stream_key)
            .arg(job_stream_id)
            .arg(job_stream_id)
            .query_async(&mut conn)
            .await;

        let entry = match range_res {
            Ok(redis::Value::Array(items)) => items.into_iter().next(),
            _ => None,
        };

        if let Some(entry_val) = entry {
            if let Some(queued_job) = parse_stream_entry(&entry_val, "system")? {
                let next_retry = queued_job.retry_count + 1;

                if next_retry < queued_job.max_retries {
                    // Re-enqueue with incremented retry count
                    self.push_envelope(
                        queued_job.job,
                        next_retry,
                        queued_job.max_retries,
                        Some(reason.to_string()),
                    )
                    .await?;
                } else {
                    // Push to Dead-Letter Queue
                    let job_json = serde_json::to_string(&queued_job.job)
                        .map_err(|e| QueueError::Serialization(e.to_string()))?;
                    let failed_at = Utc::now().to_rfc3339();

                    let _: String = redis::cmd("XADD")
                        .arg(&self.dead_letter_stream_key)
                        .arg("*")
                        .arg("job_payload")
                        .arg(&job_json)
                        .arg("total_attempts")
                        .arg(next_retry.to_string())
                        .arg("failed_at")
                        .arg(&failed_at)
                        .arg("failure_reason")
                        .arg(reason)
                        .query_async(&mut conn)
                        .await
                        .map_err(|e| QueueError::Redis(e.to_string()))?;
                }
            }
        }

        // Acknowledge and remove the failed message instance from the main stream
        self.ack(job_stream_id).await?;
        Ok(())
    }

    /// Returns the number of dead-lettered jobs in the DLQ stream.
    pub async fn dead_letter_count(&self) -> Result<usize, QueueError> {
        let mut conn = self.conn().await?;
        let len: usize = redis::cmd("XLEN")
            .arg(&self.dead_letter_stream_key)
            .query_async(&mut conn)
            .await
            .map_err(|e| QueueError::Redis(e.to_string()))?;
        Ok(len)
    }
}

/// Helper to parse a Redis stream message entry into a `QueuedJob`.
fn parse_stream_entry(
    entry: &redis::Value,
    consumer: &str,
) -> Result<Option<QueuedJob>, QueueError> {
    if let redis::Value::Array(parts) = entry {
        if parts.len() < 2 {
            return Ok(None);
        }

        let stream_id = match &parts[0] {
            redis::Value::BulkString(bytes) => String::from_utf8_lossy(bytes).to_string(),
            redis::Value::SimpleString(s) => s.clone(),
            _ => return Ok(None),
        };

        let mut job_payload: Option<String> = None;
        let mut retry_count: u32 = 0;
        let mut max_retries: u32 = DEFAULT_MAX_RETRIES;
        let mut created_at: DateTime<Utc> = Utc::now();
        let mut last_error: Option<String> = None;

        if let redis::Value::Array(fields) = &parts[1] {
            let mut iter = fields.iter();
            while let (Some(k), Some(v)) = (iter.next(), iter.next()) {
                let key_str = match k {
                    redis::Value::BulkString(b) => String::from_utf8_lossy(b).to_string(),
                    redis::Value::SimpleString(s) => s.clone(),
                    _ => continue,
                };
                let val_str = match v {
                    redis::Value::BulkString(b) => String::from_utf8_lossy(b).to_string(),
                    redis::Value::SimpleString(s) => s.clone(),
                    _ => continue,
                };

                match key_str.as_str() {
                    "job_payload" => job_payload = Some(val_str),
                    "retry_count" => retry_count = val_str.parse().unwrap_or(0),
                    "max_retries" => max_retries = val_str.parse().unwrap_or(DEFAULT_MAX_RETRIES),
                    "created_at" => {
                        if let Ok(dt) = DateTime::parse_from_rfc3339(&val_str) {
                            created_at = dt.with_timezone(&Utc);
                        }
                    }
                    "last_error" if !val_str.is_empty() => {
                        last_error = Some(val_str);
                    }
                    _ => {}
                }
            }
        }

        if let Some(raw_json) = job_payload {
            let job: Job = serde_json::from_str(&raw_json).map_err(|e| {
                QueueError::InvalidPayload(format!("Failed deserializing Job JSON: {e}"))
            })?;

            return Ok(Some(QueuedJob {
                stream_id,
                job,
                retry_count,
                max_retries,
                created_at,
                claimed_at: Some(Utc::now()),
                claimed_by: Some(consumer.to_string()),
                last_error,
            }));
        }
    }

    Ok(None)
}

// -----------------------------------------------------------------------------
// In-Memory Test / Simulation Queue
// -----------------------------------------------------------------------------

/// Thread-safe in-memory job queue for unit testing and local simulation.
#[derive(Clone, Default)]
pub struct InMemoryJobQueue {
    queue: Arc<RwLock<VecDeque<QueuedJob>>>,
    in_flight: Arc<RwLock<HashMap<String, QueuedJob>>>,
    dead_letter: Arc<RwLock<Vec<QueuedJob>>>,
    claim_timeout: Duration,
    max_retries: u32,
    counter: Arc<RwLock<u64>>,
}

impl InMemoryJobQueue {
    /// Creates a new in-memory job queue.
    pub fn new() -> Self {
        Self {
            queue: Arc::new(RwLock::new(VecDeque::new())),
            in_flight: Arc::new(RwLock::new(HashMap::new())),
            dead_letter: Arc::new(RwLock::new(Vec::new())),
            claim_timeout: Duration::from_secs(DEFAULT_CLAIM_TIMEOUT_SECS),
            max_retries: DEFAULT_MAX_RETRIES,
            counter: Arc::new(RwLock::new(0)),
        }
    }

    /// Sets claim timeout.
    pub fn with_claim_timeout(mut self, timeout: Duration) -> Self {
        self.claim_timeout = timeout;
        self
    }

    /// Sets max retries.
    pub fn with_max_retries(mut self, max_retries: u32) -> Self {
        self.max_retries = max_retries;
        self
    }

    /// Enqueues a job.
    pub async fn push(&self, job: Job) -> Result<String, QueueError> {
        let mut count = self.counter.write().await;
        *count += 1;
        let stream_id = format!("mem-{count}");

        let queued = QueuedJob {
            stream_id: stream_id.clone(),
            job,
            retry_count: 0,
            max_retries: self.max_retries,
            created_at: Utc::now(),
            claimed_at: None,
            claimed_by: None,
            last_error: None,
        };

        self.queue.write().await.push_back(queued);
        Ok(stream_id)
    }

    /// Claims next available job or reclaims timed-out job.
    pub async fn claim(&self, consumer_name: &str) -> Result<Option<QueuedJob>, QueueError> {
        let now = Utc::now();

        // 1. Check for expired in-flight jobs
        let mut in_flight = self.in_flight.write().await;
        let mut expired_id = None;
        for (id, job) in in_flight.iter() {
            if let Some(claimed_at) = job.claimed_at {
                if now - claimed_at > chrono::Duration::from_std(self.claim_timeout).unwrap() {
                    expired_id = Some(id.clone());
                    break;
                }
            }
        }

        if let Some(id) = expired_id {
            if let Some(mut job) = in_flight.remove(&id) {
                job.claimed_at = Some(now);
                job.claimed_by = Some(consumer_name.to_string());
                in_flight.insert(job.stream_id.clone(), job.clone());
                return Ok(Some(job));
            }
        }

        // 2. Claim from pending queue
        let mut queue = self.queue.write().await;
        if let Some(mut job) = queue.pop_front() {
            job.claimed_at = Some(now);
            job.claimed_by = Some(consumer_name.to_string());
            in_flight.insert(job.stream_id.clone(), job.clone());
            return Ok(Some(job));
        }

        Ok(None)
    }

    /// Acknowledges and completes job.
    pub async fn ack(&self, job_stream_id: &str) -> Result<(), QueueError> {
        let mut in_flight = self.in_flight.write().await;
        in_flight.remove(job_stream_id);
        Ok(())
    }

    /// Fails job and increments retries or moves to DLQ.
    pub async fn fail(&self, job_stream_id: &str, reason: &str) -> Result<(), QueueError> {
        let mut in_flight = self.in_flight.write().await;
        if let Some(mut job) = in_flight.remove(job_stream_id) {
            job.retry_count += 1;
            job.last_error = Some(reason.to_string());
            job.claimed_at = None;
            job.claimed_by = None;

            if job.retry_count < job.max_retries {
                self.queue.write().await.push_back(job);
            } else {
                self.dead_letter.write().await.push(job);
            }
        }
        Ok(())
    }

    /// Heartbeats job to renew claim.
    pub async fn heartbeat(&self, job_stream_id: &str) -> Result<(), QueueError> {
        let mut in_flight = self.in_flight.write().await;
        if let Some(job) = in_flight.get_mut(job_stream_id) {
            job.claimed_at = Some(Utc::now());
        }
        Ok(())
    }

    /// Returns the number of dead-lettered jobs.
    pub async fn dead_letter_count(&self) -> usize {
        self.dead_letter.read().await.len()
    }

    /// Returns the pending queue length.
    pub async fn pending_count(&self) -> usize {
        self.queue.read().await.len()
    }
}
