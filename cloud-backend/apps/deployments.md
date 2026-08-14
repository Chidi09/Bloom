# App spec — `deployments`

A Deployment is a single push of an artifact/release to a platform target (TestFlight, Google Play track, web production, etc.).

---

## 1. Models

### `Deployment`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| release_id | Option<ForeignKey<Release>> | |
| artifact_id | Option<ForeignKey<Artifact>> | |
| environment_id | ForeignKey<Environment> | |
| organization_id | i64 | denormalized |
| platform | String | `ios` / `android` / `web` |
| target | String | `testflight` / `app_store` / `internal` / `closed` / `open` / `production` / `preview` |
| status | String | `pending` / `queued` / `running` / `processing` / `ready` / `live` / `failed` / `rolled_back` |
| external_id | String | platform ID |
| external_url | String | platform console link |
| error_message | String | |
| started_at | Option<DateTime<Utc>> | |
| finished_at | Option<DateTime<Utc>> | |
| created_by_id | i64 | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

---

## 2. Contracts

### `DeploymentCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct DeploymentCreateRequest {
    pub release_id: Option<String>,
    pub artifact_id: Option<String>,
    pub environment_id: String,
    pub platform: String,
    pub target: String,
}
```

Either `release_id` or `artifact_id` must be provided.

### `DeploymentResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct DeploymentResponse {
    pub id: String,
    pub release_id: Option<String>,
    pub artifact_id: Option<String>,
    pub environment_id: String,
    pub organization_id: String,
    pub platform: String,
    pub target: String,
    pub status: String,
    pub external_id: Option<String>,
    pub external_url: Option<String>,
    pub error_message: Option<String>,
    pub started_at: Option<String>,
    pub finished_at: Option<String>,
    pub created_by_id: String,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 3. Services

### `create_deployment(db, organization_id, user_id, req) -> Result<Deployment, DeploymentError>`

1. Resolve release or artifact, verify organization.
2. Resolve environment.
3. Validate platform/target combination.
4. Enforce approval rules: `app_store`, `production`, and Shorebird production require approved release.
5. Insert `Deployment` with `status = pending`.
6. Queue deploy job via Redis.
7. Emit `deployment.created` event.

### `update_deployment_status(db, deployment, status, external_id, external_url, error_message)`

Worker endpoint. Updates status and emits `deployment.processing`, `deployment.completed`, `deployment.failed`.

### `rollback_deployment(db, deployment, user_id)`

Mark `rolled_back`. For web, trigger CDN rollback. For mobile, expiring the build/track is platform-dependent; record action and emit `deployment.rolled_back`.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` non-production requires `OrganizationPermission::developer()`.
- `POST` production targets requires `OrganizationPermission::release_manager()`.

---

## 5. URLs

```rust
Router::new()
    .get("/deployments", views::list_deployments)
    .post("/deployments", views::create_deployment)
    .get("/deployments/:id", views::retrieve_deployment)
    .post("/deployments/:id/rollback", views::rollback_deployment)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE deployments_deployment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    release_id BIGINT REFERENCES releases_release(id) ON DELETE SET NULL,
    artifact_id BIGINT REFERENCES artifacts_artifact(id) ON DELETE SET NULL,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    target VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    external_id VARCHAR(255),
    external_url VARCHAR(500),
    error_message TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX deployments_deployment_release_id_idx ON deployments_deployment(release_id);
CREATE INDEX deployments_deployment_organization_id_idx ON deployments_deployment(organization_id);
CREATE INDEX deployments_deployment_status_idx ON deployments_deployment(status);

-- down
DROP TABLE deployments_deployment;
```
