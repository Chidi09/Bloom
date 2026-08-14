# App spec — `webhosting`

Bloom-owned Flutter Web hosting: preview URLs, production deployments, custom domains, deployment history, rollback.

---

## 1. Models

### `WebDeployment`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| organization_id | i64 | denormalized |
| environment_id | ForeignKey<Environment> | |
| artifact_id | ForeignKey<Artifact> | web bundle artifact |
| release_id | Option<ForeignKey<Release>> | |
| target | String | `preview` / `production` |
| url | String | deployed URL |
| storage_prefix | String | unique path prefix in object storage |
| status | String | `deploying` / `live` / `failed` / `rolled_back` |
| metadata | String | JSON headers, redirects, cache rules |
| deployed_by_id | i64 | |
| created_at | DateTime<Utc> | |

### `CustomDomain`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| organization_id | i64 | denormalized |
| domain | String | |
| certificate_status | String | `pending` / `issued` / `expired` |
| certificate_expires_at | Option<DateTime<Utc>> | |
| verified_at | Option<DateTime<Utc>> | |
| created_at | DateTime<Utc> | |

---

## 2. Contracts

### `WebDeploymentResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct WebDeploymentResponse {
    pub id: String,
    pub app_id: String,
    pub environment_id: String,
    pub release_id: Option<String>,
    pub target: String,
    pub url: String,
    pub status: String,
    pub deployed_by_id: String,
    pub created_at: String,
}
```

### `CustomDomainResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct CustomDomainResponse {
    pub id: String,
    pub app_id: String,
    pub domain: String,
    pub certificate_status: String,
    pub certificate_expires_at: Option<String>,
    pub verified_at: Option<String>,
}
```

---

## 3. Services

### `deploy_web(db, organization_id, user_id, req) -> Result<WebDeployment, WebHostingError>`

1. Resolve artifact (web bundle) and environment.
2. Generate URL: `https://{branch}-{app_slug}-{project_slug}.bloomcloud.dev` for preview, or production domain.
3. Queue deploy worker to upload bundle to storage prefix and invalidate CDN.
4. Insert `WebDeployment` with `status = deploying`.
5. Emit `webhosting.deployed` on completion.

### `rollback_web_deployment(db, deployment, user_id)`

Restore previous deployment's storage prefix as current. Emit `webhosting.rolled_back`.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` preview requires `OrganizationPermission::developer()`.
- `POST` production requires `OrganizationPermission::release_manager()`.

---

## 5. URLs

```rust
Router::new()
    .get("/webhosting/deployments", views::list_web_deployments)
    .post("/webhosting/deployments", views::deploy_web)
    .get("/webhosting/deployments/:id", views::retrieve_web_deployment)
    .post("/webhosting/deployments/:id/rollback", views::rollback_web_deployment)
    .get("/webhosting/domains", views::list_custom_domains)
    .post("/webhosting/domains", views::create_custom_domain)
    .delete("/webhosting/domains/:id", views::delete_custom_domain)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE webhosting_webdeployment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    artifact_id BIGINT NOT NULL REFERENCES artifacts_artifact(id) ON DELETE CASCADE,
    release_id BIGINT REFERENCES releases_release(id) ON DELETE SET NULL,
    target VARCHAR(32) NOT NULL,
    url VARCHAR(500) NOT NULL,
    storage_prefix VARCHAR(500) NOT NULL,
    status VARCHAR(32) NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    deployed_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX webhosting_webdeployment_app_id_idx ON webhosting_webdeployment(app_id);

CREATE TABLE webhosting_customdomain (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    domain VARCHAR(255) NOT NULL,
    certificate_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    certificate_expires_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, domain)
);

CREATE INDEX webhosting_customdomain_app_id_idx ON webhosting_customdomain(app_id);

-- down
DROP TABLE webhosting_customdomain;
DROP TABLE webhosting_webdeployment;
```
