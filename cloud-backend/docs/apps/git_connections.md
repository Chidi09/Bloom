# App spec — `git_connections`

Git provider OAuth/app connections and webhook handling.

---

## 1. Models

### `GitConnection`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| provider | String | `github` / `gitlab` / `bitbucket` |
| installation_id | String | external app/installation ID |
| encrypted_access_token | String | ciphertext |
| metadata | String | JSON account/permissions |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

---

## 2. Contracts

### `GitConnectionResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct GitConnectionResponse {
    pub id: String,
    pub organization_id: String,
    pub provider: String,
    pub installation_id: String,
    pub metadata: serde_json::Value,
    pub created_at: String,
}
```

### `RepositoryResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct RepositoryResponse {
    pub id: String,
    pub full_name: String,
    pub default_branch: String,
    pub url: String,
}
```

---

## 3. Services

### `connect_provider(...)`

OAuth/app flow. Store encrypted token.

### `list_repositories(db, connection) -> Result<Vec<RepositoryResponse>, GitError>`

Call provider API and return list.

### `handle_webhook(provider, payload, signature, delivery_id)`

1. Verify signature.
2. Deduplicate by delivery ID.
3. Emit `git.push` or `git.pull_request` event.
4. Optionally enqueue async task `process_git_push` to create build.

---

## 4. Permissions

- Connection management requires `OrganizationPermission::admin()`.
- Webhooks are unauthenticated at route level but signature-verified.

---

## 5. URLs

```rust
Router::new()
    .get("/git-connections", views::list_connections)
    .post("/git-connections", views::create_connection)
    .get("/git-connections/:id", views::retrieve_connection)
    .get("/git-connections/:id/repositories", views::list_repositories)
    .delete("/git-connections/:id", views::delete_connection)
```

Webhooks:

```rust
Router::new()
    .post("/webhooks/github", views::github_webhook)
    .post("/webhooks/gitlab", views::gitlab_webhook)
    .post("/webhooks/bitbucket", views::bitbucket_webhook)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE git_connections_gitconnection (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    installation_id VARCHAR(255) NOT NULL,
    encrypted_access_token TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX git_connections_gitconnection_organization_id_idx ON git_connections_gitconnection(organization_id);

-- down
DROP TABLE git_connections_gitconnection;
```
