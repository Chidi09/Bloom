# App spec — `workers`

The `workers` app is the API surface between the control plane and build/deploy worker pools. It is not a domain app in the traditional sense; it exposes internal endpoints that workers call to claim jobs, report progress, and fetch secrets.

---

## 1. Scope

This app is responsible for:

- Worker job claiming (`/api/v1/workers/jobs/claim`).
- Build stage reporting.
- Artifact registration.
- Build/deployment completion reporting.
- Secure delivery of secrets, credentials, and signing materials to workers.

It does **not** execute builds or deployments itself.

---

## 2. Models

No persistent models unique to this app. It operates on `builds::Build`, `deployments::Deployment`, `artifacts::Artifact`, `secrets::Secret`, `credentials::Credential`, and `signing::SigningIdentity`.

A `WorkerSession` table is optional for tracking active workers:

### `WorkerSession` (optional)

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| worker_id | String | |
| started_at | DateTime<Utc> | |
| last_seen_at | DateTime<Utc> | |
| metadata | String | JSON (version, capabilities) |

---

## 3. Worker authentication

Workers authenticate with short-lived job tokens (JWT). See [`infrastructure.md`](../infrastructure.md#5-worker-authentication).

Endpoints in this app require the `JobTokenLayer` middleware.

---

## 4. Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/workers/jobs/claim` | Worker claims next available build or deploy job |
| POST | `/api/v1/workers/jobs/:id/stage` | Report build stage status |
| POST | `/api/v1/workers/jobs/:id/artifact` | Register an artifact |
| POST | `/api/v1/workers/jobs/:id/complete` | Mark build/deploy complete/failed |
| GET | `/api/v1/workers/jobs/:id/secrets` | Fetch decrypted secrets for this job |
| GET | `/api/v1/workers/jobs/:id/credentials` | Fetch decrypted platform credentials |
| GET | `/api/v1/workers/jobs/:id/signing` | Fetch decrypted signing materials |
| POST | `/api/v1/workers/heartbeat` | Optional worker liveness ping |

---

## 5. Job claiming

### `claim_job(db) -> Result<Option<WorkerJob>, WorkerError>`

1. Look for pending build jobs first, then pending deploy jobs.
2. Select one with `SELECT ... FOR UPDATE SKIP LOCKED` via Redis queue or database row lock.
3. Mark job as `running`.
4. Generate job token.
5. Return job details + token.

### `WorkerJob` response

```rust
#[derive(Debug, Clone, Serialize)]
pub struct WorkerJob {
    pub job_id: String,
    pub job_token: String,
    pub job_type: String, // "build" | "deploy"
    pub expires_at: String,
    pub payload: WorkerJobPayload,
}
```

---

## 6. Stage reporting

### `report_stage(db, job_id, req) -> Result<(), WorkerError>`

Request:

```rust
pub struct StageReportRequest {
    pub stage: String,
    pub status: String, // "running" | "completed" | "failed" | "skipped"
    pub log_snippet: Option<String>,
}
```

Actions:

1. Verify job token matches `job_id`.
2. Update `BuildStage`.
3. Emit `build.stage.started` / `build.stage.completed` / `build.stage.failed`.

---

## 7. Artifact registration

### `register_artifact(db, job_id, req) -> Result<ArtifactResponse, WorkerError>`

Request:

```rust
pub struct WorkerArtifactRequest {
    pub platform: String,
    pub kind: String,
    pub storage_key: String,
    pub storage_bucket: String,
    pub file_name: String,
    pub file_size: i64,
    pub checksum: String,
    pub version: String,
    pub build_number: i64,
    pub metadata: serde_json::Value,
}
```

Actions:

1. Verify storage key exists (HEAD request).
2. Insert `Artifact`.
3. Emit `artifact.created` and `artifact.uploaded`.

---

## 8. Completion reporting

### `complete_job(db, job_id, req) -> Result<(), WorkerError>`

Request:

```rust
pub struct JobCompleteRequest {
    pub status: String, // "success" | "failed" | "cancelled"
    pub metadata: serde_json::Value,
    pub error_message: Option<String>,
}
```

Actions:

1. Update `Build` or `Deployment`.
2. Set `finished_at`.
3. Emit `build.completed` / `build.failed` / `deployment.completed` / `deployment.failed`.

---

## 9. Secret/credential/signing delivery

These endpoints verify the job token claims match the job's organization and environment, then decrypt and return plaintext.

Response shapes:

```rust
pub struct WorkerSecretsResponse {
    pub env_vars: Vec<WorkerSecret>,
}

pub struct WorkerCredentialsResponse {
    pub credentials: Vec<WorkerCredential>,
}

pub struct WorkerSigningResponse {
    pub identities: Vec<WorkerSigningIdentity>,
}
```

Decrypt using `Crypto::decrypt`. Never log plaintext.

---

## 10. Permissions

All endpoints require a valid job token. No organization role checks; the token carries the authorization.

---

## 11. Notes

- Job tokens are single-use in the sense that they are scoped to one job; they can be reused during the job's lifetime.
- Secrets are delivered as a bundle, not individually, to minimize API calls.
- Worker endpoints are internal and should not be exposed publicly; use a separate subdomain or ingress rule if needed (`workers.bloomcloud.dev`).
