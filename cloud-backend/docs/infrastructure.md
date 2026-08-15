# Infrastructure — Bloom Cloud Backend

This document describes the cross-cutting infrastructure concerns: storage, queue, events, crypto, and worker authentication. It is not a domain app; it is shared by the API and workers.

---

## 1. Object storage (`src/infra/storage.rs`)

### Abstraction

```rust
#[async_trait]
pub trait ObjectStorage: Send + Sync + 'static {
    async fn put(&self, key: &str, body: bytes::Bytes, content_type: &str) -> Result<(), StorageError>;
    async fn get(&self, key: &str) -> Result<bytes::Bytes, StorageError>;
    async fn delete(&self, key: &str) -> Result<(), StorageError>;
    async fn presigned_url(&self, key: &str, expires_in: Duration) -> Result<String, StorageError>;
    async fn exists(&self, key: &str) -> Result<bool, StorageError>;
}
```

### Implementation

Use `aws-sdk-s3` configured for R2/S3-compatible endpoints. Configuration from env:

- `STORAGE_ENDPOINT` (optional)
- `STORAGE_BUCKET`
- `STORAGE_ACCESS_KEY_ID`
- `STORAGE_SECRET_ACCESS_KEY`
- `STORAGE_REGION` (default `auto`)

For local tests, provide an in-memory implementation.

### Key structure

```text
orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/builds/{build_public_id}/artifacts/{artifact_public_id}/{filename}
```

Use the public UUIDs, not internal ids, so keys are stable across exports/imports and do not leak schema internals.

### Presigned URLs

Presigned URLs are generated server-side and returned to clients. Default expiry: 15 minutes. Artifacts and build logs are served this way. Never return raw storage URLs.

---

## 2. Job queue (`src/infra/queue.rs`)

Bloom Cloud uses **two** distinct mechanisms for background work:

1. **Redis-based job queue** for build/deploy workers. These jobs need platform-specific containers, job-scoped tokens, and artifact lifecycle, so they are custom.
2. **`djangors-tasks`** for side effects: emails, webhook async processing, platform polling, cleanup, audit snapshots.

### Redis build/deploy queue

Use Redis Streams. Jobs are JSON payloads with a job id, type, payload, and retry count.

```rust
pub struct JobQueue {
    redis: redis::Client,
    stream_key: String,
    consumer_group: String,
}

impl JobQueue {
    pub async fn push(&self, job: Job) -> Result<(), QueueError>;
    pub async fn claim(&self, consumer_name: &str) -> Result<Option<Job>, QueueError>;
    pub async fn ack(&self, job_id: &str) -> Result<(), QueueError>;
    pub async fn fail(&self, job_id: &str, reason: &str) -> Result<(), QueueError>;
}
```

### Job payload

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "job_type")]
pub enum Job {
    Build {
        build_id: String, // public_id
        organization_id: String,
        project_id: String,
        app_id: String,
        environment_id: String,
        git_commit: String,
        platform: String,
        build_profile: String,
    },
    Deploy {
        deployment_id: String,
        organization_id: String,
        release_id: Option<String>,
        artifact_id: String,
        platform: String,
        target: String,
    },
    Webhook {
        delivery_id: String,
        provider: String,
        payload: serde_json::Value,
        signature: String,
    },
}
```

### Redis streams

- Stream: `bloomcloud:jobs`
- Consumer group: `workers`
- Claim uses XREADGROUP with BLOCK and COUNT 1.
- Failed jobs are moved to a dead-letter stream after 3 retries.

### Djangors tasks for side effects

For everything that is not a build/deploy job, use `djangors-tasks`.

```rust
use djangors::tasks::{task, enqueue};
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
pub struct SendEmailPayload {
    pub to: String,
    pub subject: String,
    pub body: String,
}

#[task]
pub async fn send_email(payload: SendEmailPayload) -> Result<(), djangors_tasks::TaskError> {
    // send email
    Ok(())
}

// enqueue from a handler
enqueue(db, "send_email", &payload).await?;
```

Recurring tasks:

```rust
use djangors::tasks::{register_recurring, tick_recurring_tasks};

register_recurring(db, "cleanup_expired_builds", &EmptyPayload {}, "0 2 * * *").await?;
```

Worker loop:

```rust
use djangors::tasks::Worker;
use std::time::Duration;

let worker = Worker::new(db)
    .with_poll_interval(Duration::from_secs(1))
    .with_recurring_tick_interval(Duration::from_secs(60));
worker.run().await;
```

Task handlers live in `src/apps/<app>/tasks.rs` and are registered via `#[task]`. The task registry is global at compile time.

---

## 3. Events system (`src/infra/events.rs`)

Every state change emits an event. Events are both:

1. Pushed to Redis pub/sub channel `bloomcloud:events` for real-time dashboard updates.
2. Stored in `events_eventlog` table for replay/debugging.

### Event schema

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub event_id: String, // UUID v4
    pub event_type: String,
    pub organization_id: Option<String>,
    pub project_id: Option<String>,
    pub app_id: Option<String>,
    pub actor_id: Option<String>,
    pub payload: serde_json::Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

### Event types

See [`events.md`](events.md) for the canonical list. The infrastructure only transports and stores them.

### Publishing

```rust
pub async fn publish(&self, event: Event) -> Result<(), EventError> {
    let json = serde_json::to_string(&event)?;
    // publish to Redis channel
    // insert into EventLog table
}
```

Events must be durable: publish to Redis first, then store in DB. If DB insert fails, log and continue; the event is still delivered via Redis.

---

## 4. Encryption (`src/infra/crypto.rs`)

### Master key

Master encryption key is read from environment:

- `ENCRYPTION_KEY` — hex-encoded 256-bit key.

### Ciphertext format

Use AES-256-GCM with a random 96-bit nonce. Store as:

```text
v1:{base64(nonce + tag + ciphertext)}
```

Prefix `v1:` allows future key rotation. The key itself never rotates data; instead, re-encrypt on read.

### API

```rust
pub struct Crypto;

impl Crypto {
    pub fn encrypt(plaintext: &str) -> Result<String, CryptoError>;
    pub fn decrypt(ciphertext: &str) -> Result<String, CryptoError>;
    pub fn hash_token(token: &str) -> String; // sha256 hex
}
```

### Secrets and credentials

All secrets, credentials, signing materials, and tokens at rest are encrypted with this utility. The only plaintext stored is the `token_hash` of API tokens for lookup.

---

## 5. Worker authentication (`src/infra/worker_auth.rs`)

Workers are untrusted network peers that run code. They authenticate with short-lived job tokens.

### Token issuance

When a worker claims a job via the API endpoint `/api/v1/workers/jobs/claim`, the API returns:

```json
{
  "job_id": "uuid",
  "job_token": "jwt",
  "expires_at": "..."
}
```

The token is a JWT signed by the API secret with claims:

```json
{
  "sub": "job:uuid",
  "job_id": "uuid",
  "job_type": "build|deploy|webhook",
  "organization_id": "uuid",
  "exp": 1723600000
}
```

### Token validation

Middleware `JobTokenLayer` validates the token, extracts `JobTokenClaims`, and puts them in request extensions. Endpoints that accept worker reports use `require_job_token()` to extract claims and ensure the token matches the job id in the path.

### Worker endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/workers/jobs/claim` | worker claims next available job |
| POST | `/api/v1/workers/jobs/{id}/stage` | worker reports build stage |
| POST | `/api/v1/workers/jobs/{id}/artifact` | worker registers artifact |
| POST | `/api/v1/workers/jobs/{id}/complete` | worker marks job complete/failed |
| GET | `/api/v1/workers/jobs/{id}/secrets` | worker fetches decrypted secrets for this job |
| GET | `/api/v1/workers/jobs/{id}/credentials` | worker fetches decrypted platform credentials |
| GET | `/api/v1/workers/jobs/{id}/signing` | worker fetches decrypted signing materials |

These endpoints are internal and not exposed to dashboard/CLI users.

---

## 6. Worker primitives

### Worker configuration

Workers read env:

- `BLOOM_CLOUD_API_URL`
- `BLOOM_CLOUD_WORKER_TOKEN` (optional long-lived worker registration token for pool auth)
- `BLOOM_CLOUD_JOB_TOKEN` (short-lived per-job token)

### Worker job loop

```rust
loop {
    let job = claim_job().await?;
    if let Some(job) = job {
        run_job(job).await;
    } else {
        sleep(Duration::from_secs(5)).await;
    }
}
```

---

## 7. Typed settings and dual backend

### Typed settings

Use `#[derive(djangors_macros::Settings)]` for application-specific configuration instead of manual `std::env::var` parsing.

```rust
#[derive(djangors_macros::Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM")]
pub struct BloomCloudSettings {
    pub api_url: String,
    #[djangors(default = "https://api.bloomcloud.dev".to_string())]
    pub dashboard_url: String,
    #[djangors(default = 30)]
    pub worker_claim_timeout_secs: u64,
    pub storage_bucket: String,
    pub storage_access_key_id: String,
    pub storage_secret_access_key: String,
    pub encryption_key: String,
    pub sentry_dsn: Option<String>,
    #[djangors(default = false)]
    pub enable_sqlite_backend: bool,
}
```

`load()` is called once at startup and failures are hard boot errors.

### Dual backend

Djangors 0.7.0 supports both PostgreSQL and SQLite. Bloom Cloud targets PostgreSQL in production, but migrations and ORM queries should be written to work on SQLite for local development and fast tests where possible.

- Use `Database::connect(&config)` and let it infer the dialect from `DATABASE_URL`.
- Use `Database::transaction_conn` for dual-backend transactions.
- Avoid Postgres-only raw SQL in application code; if unavoidable, gate it behind `Dialect::Postgres` and document the SQLite limitation.
- The `djangors-test` harness is still Postgres-oriented for isolation; SQLite in-memory is used only for lightweight unit tests.

---

## 8. Tests

All infrastructure modules must have unit tests in `tests/infra/`.

### Storage tests

- Roundtrip put/get/delete.
- Presigned URL exists and is non-empty.
- In-memory backend used for tests.

### Queue tests

- Push and claim job.
- Ack removes job from pending.
- Failed job retried and moved to dead letter after 3 retries.

### Events tests

- Publish event and read from Redis channel.
- Event stored in `EventLog` table.

### Crypto tests

- Encrypt/decrypt roundtrip.
- Different plaintexts produce different ciphertexts.
- Decrypting tampered ciphertext fails.

### Worker auth tests

- Valid job token authenticates.
- Expired token rejected.
- Token with wrong job id rejected for job-specific endpoints.

---

## 9. Notes

- Redis is used for cache, queue, and pub/sub. Use separate logical databases only if needed; prefer key prefixes.
- Object storage is eventually consistent. Workers must verify upload success via ETag/head request before registering artifact.
- Encryption keys must be rotated only by re-encrypting rows on read; never expose plaintext during migration.
