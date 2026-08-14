# App spec — `artifacts`

Artifact metadata and presigned download URLs. Artifact bytes live in object storage.

---

## 1. Models

### `Artifact`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| build_id | ForeignKey<Build> | |
| organization_id | i64 | denormalized |
| platform | String | `android` / `ios` / `web` |
| kind | String | `ipa` / `aab` / `apk` / `web_bundle` / `dsym` / `source_map` / `mapping` / `log` |
| storage_key | String | |
| storage_bucket | String | |
| file_name | String | |
| file_size | i64 | bytes |
| checksum | String | sha256 |
| version | String | app version |
| build_number | i64 | integer build number |
| metadata | String | JSON |
| created_at | DateTime<Utc> | |

---

## 2. Contracts

### `ArtifactResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct ArtifactResponse {
    pub id: String,
    pub build_id: String,
    pub organization_id: String,
    pub platform: String,
    pub kind: String,
    pub file_name: String,
    pub file_size: i64,
    pub checksum: String,
    pub version: String,
    pub build_number: i64,
    pub metadata: serde_json::Value,
    pub download_url: Option<String>,
    pub created_at: String,
}
```

---

## 3. Services

### `register_artifact(db, build_id, organization_id, req) -> Result<Artifact, ArtifactError>`

Worker endpoint. Inserts artifact metadata after confirming upload to storage.

### `presigned_download_url(db, artifact, expires_in) -> Result<String, ArtifactError>`

Generates a short-lived presigned URL. Default 15 minutes.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` is internal worker only (job token).

---

## 5. URLs

```rust
Router::new()
    .get("/artifacts", views::list_artifacts)
    .get("/artifacts/:id", views::retrieve_artifact)
    .get("/artifacts/:id/download", views::download_artifact)
```

Plus internal worker endpoint `/api/v1/workers/jobs/:id/artifact`.

---

## 6. Migration

```sql
-- up
CREATE TABLE artifacts_artifact (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    build_id BIGINT NOT NULL REFERENCES builds_build(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    storage_key VARCHAR(500) NOT NULL,
    storage_bucket VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    checksum VARCHAR(64) NOT NULL,
    version VARCHAR(64) NOT NULL,
    build_number BIGINT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX artifacts_artifact_build_id_idx ON artifacts_artifact(build_id);
CREATE INDEX artifacts_artifact_organization_id_idx ON artifacts_artifact(organization_id);

-- down
DROP TABLE artifacts_artifact;
```
