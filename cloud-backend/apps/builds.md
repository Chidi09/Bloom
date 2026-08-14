# App spec — `builds`

The `builds` app manages build records, status transitions, build stages, and logs. It pushes actual build execution to workers via the Redis job queue.

---

## 1. Models

### `Build`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| organization_id | i64 | denormalized |
| environment_id | ForeignKey<Environment> | |
| git_commit | String | SHA |
| git_branch | String | |
| git_ref | String | tag or ref |
| status | String | `pending` / `queued` / `running` / `success` / `failed` / `cancelled` |
| platform | String | `android` / `ios` / `web` / `all` |
| build_profile | String | |
| flutter_version | String | resolved version |
| dart_version | String | resolved version |
| bloom_version | String | resolved version |
| flavor | String | optional |
| started_at | Option<DateTime<Utc>> | |
| finished_at | Option<DateTime<Utc>> | |
| logs_url | String | optional storage key |
| worker_id | String | optional worker identifier |
| metadata | String | JSON worker reports |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

### `BuildStage`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| build_id | ForeignKey<Build> | |
| stage | String | `checkout`, `install`, `resolve`, `generate`, `prebuild`, `test`, `analyze`, `build`, `upload` |
| status | String | `pending` / `running` / `completed` / `failed` / `skipped` |
| started_at | Option<DateTime<Utc>> | |
| finished_at | Option<DateTime<Utc>> | |
| log_snippet | String | optional tail of logs |
| created_at | DateTime<Utc> | |

---

## 2. Contracts

### `BuildCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct BuildCreateRequest {
    pub app_id: String,
    pub environment_id: String,
    pub platform: String,
    pub git_commit: Option<String>,
    pub git_branch: Option<String>,
    pub git_ref: Option<String>,
    pub build_profile: Option<String>,
    pub flutter_version: Option<String>,
    pub dart_version: Option<String>,
    pub bloom_version: Option<String>,
    pub flavor: Option<String>,
}
```

### `BuildResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct BuildResponse {
    pub id: String,
    pub app_id: String,
    pub environment_id: String,
    pub organization_id: String,
    pub git_commit: String,
    pub git_branch: String,
    pub git_ref: String,
    pub status: String,
    pub platform: String,
    pub build_profile: String,
    pub flutter_version: String,
    pub dart_version: String,
    pub bloom_version: String,
    pub flavor: Option<String>,
    pub started_at: Option<String>,
    pub finished_at: Option<String>,
    pub logs_url: Option<String>,
    pub stages: Vec<BuildStageResponse>,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 3. Services

### `create_build(db, organization_id, user_id, req) -> Result<Build, BuildError>`

1. Resolve app and environment, verify organization.
2. Resolve git defaults from app if not provided.
3. Apply environment defaults for profile/versions.
4. Insert `Build` with `status = pending`.
5. Create `BuildStage` rows for each stage.
6. Emit `build.created` event.
7. Queue build job via Redis `JobQueue`.
8. Emit `build.queued` event.

### `cancel_build(db, build, user_id) -> Result<Build, BuildError>`

Only `pending` or `queued` builds can be cancelled. `running` builds send a cancel signal to the worker (worker must check a cancel key in Redis).

### `update_stage(db, build_id, stage, status, log_snippet) -> Result<(), BuildError>`

Worker endpoint: update a build stage. Emit `build.stage.started` / `build.stage.completed` / `build.stage.failed`.

### `complete_build(db, build_id, status, metadata) -> Result<(), BuildError>`

Worker endpoint: mark build complete/failed. Emit `build.completed` or `build.failed`.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` / `cancel` requires `OrganizationPermission::developer()`.

---

## 5. URLs

```rust
Router::new()
    .get("/builds", views::list_builds)
    .post("/builds", views::create_build)
    .get("/builds/:id", views::retrieve_build)
    .post("/builds/:id/cancel", views::cancel_build)
    .get("/builds/:id/logs", views::build_logs)
```

Plus internal worker endpoints under `/api/v1/workers/jobs/:id/stage` and `/api/v1/workers/jobs/:id/complete`.

---

## 6. Migration

```sql
-- up
CREATE TABLE builds_build (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    git_commit VARCHAR(40),
    git_branch VARCHAR(255),
    git_ref VARCHAR(255),
    status VARCHAR(32) NOT NULL,
    platform VARCHAR(32) NOT NULL,
    build_profile VARCHAR(32) NOT NULL,
    flutter_version VARCHAR(64),
    dart_version VARCHAR(64),
    bloom_version VARCHAR(64),
    flavor VARCHAR(64),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    logs_url VARCHAR(500),
    worker_id VARCHAR(64),
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX builds_build_app_id_idx ON builds_build(app_id);
CREATE INDEX builds_build_organization_id_idx ON builds_build(organization_id);
CREATE INDEX builds_build_status_idx ON builds_build(status);

CREATE TABLE builds_buildstage (
    id BIGSERIAL PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds_build(id) ON DELETE CASCADE,
    stage VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    log_snippet TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(build_id, stage)
);

CREATE INDEX builds_buildstage_build_id_idx ON builds_buildstage(build_id);

-- down
DROP TABLE builds_buildstage;
DROP TABLE builds_build;
```
