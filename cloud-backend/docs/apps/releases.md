# App spec — `releases`

A Release is a first-class object that groups artifacts and deployment state across platforms.

---

## 1. Models

### `Release`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| organization_id | i64 | denormalized |
| version | String | semver |
| build_number | i64 | |
| commit | String | Git SHA |
| changelog | String | markdown |
| environment_id | Option<ForeignKey<Environment>> | optional |
| status | String | `draft` / `pending_approval` / `approved` / `rolling_out` / `released` / `rolled_back` / `expired` |
| platforms | String | JSON `["ios", "android", "web"]` |
| artifacts | String | JSON list of artifact public_ids |
| rollout_status | String | JSON per-platform rollout state |
| created_by_id | i64 | auth user id |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

---

## 2. Contracts

### `ReleaseCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct ReleaseCreateRequest {
    pub app_id: String,
    pub version: String,
    pub build_number: i64,
    pub commit: String,
    pub changelog: Option<String>,
    pub environment_id: Option<String>,
    pub platforms: Vec<String>,
    pub artifact_ids: Vec<String>,
}
```

### `ReleaseApproveRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct ReleaseApproveRequest {
    pub approved: bool,
    pub reason: Option<String>,
}
```

### `ReleaseResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct ReleaseResponse {
    pub id: String,
    pub app_id: String,
    pub organization_id: String,
    pub version: String,
    pub build_number: i64,
    pub commit: String,
    pub changelog: String,
    pub environment_id: Option<String>,
    pub status: String,
    pub platforms: Vec<String>,
    pub artifacts: Vec<ArtifactResponse>,
    pub rollout_status: serde_json::Value,
    pub created_by_id: String,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 3. Services

### `create_release(db, organization_id, user_id, req) -> Result<Release, ReleaseError>`

1. Resolve app and verify organization.
2. Validate version semver-ish.
3. Resolve artifacts and verify they belong to the app/organization.
4. Insert `Release` with `status = draft`.
5. Emit `release.created` event.

### `approve_release(db, release, user_id, approved) -> Result<Release, ReleaseError>`

Only `release_manager` or `admin`/`owner` can approve. Transition to `approved` or `draft`.

### `rollback_release(db, release, user_id) -> Result<Release, ReleaseError>`

Mark release `rolled_back`. Trigger rollback of all associated live deployments.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` requires `OrganizationPermission::developer()`.
- `approve` / `rollback` requires `OrganizationPermission::release_manager()`.

---

## 5. URLs

```rust
Router::new()
    .get("/releases", views::list_releases)
    .post("/releases", views::create_release)
    .get("/releases/:id", views::retrieve_release)
    .patch("/releases/:id", views::update_release)
    .post("/releases/:id/approve", views::approve_release)
    .post("/releases/:id/rollback", views::rollback_release)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE releases_release (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    version VARCHAR(64) NOT NULL,
    build_number BIGINT NOT NULL,
    commit VARCHAR(40) NOT NULL,
    changelog TEXT NOT NULL DEFAULT '',
    environment_id BIGINT REFERENCES environments_environment(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL,
    platforms TEXT NOT NULL DEFAULT '[]',
    artifacts TEXT NOT NULL DEFAULT '[]',
    rollout_status TEXT NOT NULL DEFAULT '{}',
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX releases_release_app_id_idx ON releases_release(app_id);
CREATE INDEX releases_release_organization_id_idx ON releases_release(organization_id);
CREATE INDEX releases_release_status_idx ON releases_release(status);

-- down
DROP TABLE releases_release;
```
