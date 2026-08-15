# App spec — `observability`

Release health and platform metrics aggregation. At launch, metrics are pulled from platform APIs (TestFlight, Google Play, Shorebird) and basic web analytics. SDK-based telemetry is Phase 6.

---

## 1. Models

### `ReleaseHealthSnapshot`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| release_id | ForeignKey<Release> | |
| platform | String | |
| target | String | |
| crash_free_rate | Option<f64> | 0-1 |
| sessions | Option<i64> | |
| crashes | Option<i64> | |
| active_users | Option<i64> | |
| metric_data | String | JSON raw metrics |
| captured_at | DateTime<Utc> | |

### `PlatformMetric`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| deployment_id | ForeignKey<Deployment> | |
| metric_type | String | `crash` / `session` / `active_user` |
| value | i64 | |
| captured_at | DateTime<Utc> | |

---

## 2. Contracts

### `ReleaseHealthResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct ReleaseHealthResponse {
    pub release_id: String,
    pub overall_crash_free_rate: Option<f64>,
    pub platforms: Vec<PlatformHealth>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PlatformHealth {
    pub platform: String,
    pub target: String,
    pub crash_free_rate: Option<f64>,
    pub sessions: Option<i64>,
    pub crashes: Option<i64>,
    pub status: String,
}
```

---

## 3. Services

### `capture_health_snapshot(db, deployment) -> Result<(), ObservabilityError>`

Worker/task endpoint. Query platform API for metrics and store snapshot.

### `get_release_health(db, release_id) -> Result<ReleaseHealthResponse, ObservabilityError>`

Aggregate latest snapshots per platform/target.

### `get_app_status(db, app_id) -> Result<AppStatusResponse, ObservabilityError>`

Return current live release per environment/platform.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.

---

## 5. URLs

```rust
Router::new()
    .get("/observability/apps/:id/status", views::app_status)
    .get("/observability/releases/:id/health", views::release_health)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE observability_releasehealthsnapshot (
    id BIGSERIAL PRIMARY KEY,
    release_id BIGINT NOT NULL REFERENCES releases_release(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    target VARCHAR(32) NOT NULL,
    crash_free_rate DOUBLE PRECISION,
    sessions BIGINT,
    crashes BIGINT,
    active_users BIGINT,
    metric_data TEXT NOT NULL DEFAULT '{}',
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX observability_releasehealthsnapshot_release_id_idx ON observability_releasehealthsnapshot(release_id);

CREATE TABLE observability_platformmetric (
    id BIGSERIAL PRIMARY KEY,
    deployment_id BIGINT NOT NULL REFERENCES deployments_deployment(id) ON DELETE CASCADE,
    metric_type VARCHAR(32) NOT NULL,
    value BIGINT NOT NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX observability_platformmetric_deployment_id_idx ON observability_platformmetric(deployment_id);

-- down
DROP TABLE observability_platformmetric;
DROP TABLE observability_releasehealthsnapshot;
```
