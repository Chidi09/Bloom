# App spec — `secrets`

Per-environment secrets manager. Values are encrypted at rest. Only workers decrypt them with a valid job token.

---

## 1. Models

### `Secret`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| environment_id | ForeignKey<Environment> | |
| organization_id | i64 | denormalized |
| key | String | max 255 |
| encrypted_value | String | ciphertext |
| is_json | bool | whether value is JSON string |
| version | i64 | monotonic |
| created_by_id | i64 | |
| created_at | DateTime<Utc> | |

Unique together: `(environment_id, key)` — the latest version is the current value.

### `SecretVersion`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| secret_id | ForeignKey<Secret> | |
| encrypted_value | String | |
| version | i64 | |
| created_by_id | i64 | |
| created_at | DateTime<Utc> | |

---

## 2. Contracts

### `SecretCreateRequest` / `SecretUpdateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct SecretCreateRequest {
    pub environment_id: String,
    pub key: String,
    pub value: String, // plaintext in request, encrypted before storage
    pub is_json: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct SecretUpdateRequest {
    pub value: Option<String>,
    pub is_json: Option<bool>,
}
```

### `SecretResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct SecretResponse {
    pub id: String,
    pub environment_id: String,
    pub organization_id: String,
    pub key: String,
    pub is_json: bool,
    pub version: i64,
    pub updated_at: String,
    // value is NEVER returned
}
```

---

## 3. Services

### `create_or_update_secret(db, organization_id, user_id, req) -> Result<Secret, SecretError>`

1. Resolve environment, verify organization.
2. Validate key format (alphanumeric + underscore, no leading digit, max 255).
3. Encrypt value with `Crypto::encrypt`.
4. If secret exists for `(environment_id, key)`, create new `SecretVersion` and increment `Secret.version`.
5. Otherwise insert new `Secret`.
6. Emit `secret.created` or `secret.updated` event.

### `rollback_secret(db, secret, user_id, target_version) -> Result<Secret, SecretError>`

Copy target version's encrypted value to current. Emit `secret.rolled_back`.

### `decrypt_for_worker(db, secret_id, job_token_claims) -> Result<String, SecretError>`

Internal endpoint. Verify job token claims match the secret's organization/environment, then decrypt and return plaintext.

---

## 4. Permissions

- `GET` / `POST` / `PATCH` / `rollback` requires `OrganizationPermission::release_manager()`.
- Viewers can see key names but not values.

---

## 5. URLs

```rust
Router::new()
    .get("/secrets", views::list_secrets)
    .post("/secrets", views::create_or_update_secret)
    .get("/secrets/:id", views::retrieve_secret)
    .patch("/secrets/:id", views::update_secret)
    .post("/secrets/:id/rollback", views::rollback_secret)
    .delete("/secrets/:id", views::delete_secret)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE secrets_secret (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    encrypted_value TEXT NOT NULL,
    is_json BOOLEAN NOT NULL DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(environment_id, key)
);

CREATE INDEX secrets_secret_environment_id_idx ON secrets_secret(environment_id);
CREATE INDEX secrets_secret_organization_id_idx ON secrets_secret(organization_id);

CREATE TABLE secrets_secretversion (
    id BIGSERIAL PRIMARY KEY,
    secret_id BIGINT NOT NULL REFERENCES secrets_secret(id) ON DELETE CASCADE,
    encrypted_value TEXT NOT NULL,
    version BIGINT NOT NULL,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX secrets_secretversion_secret_id_idx ON secrets_secretversion(secret_id);

-- down
DROP TABLE secrets_secretversion;
DROP TABLE secrets_secret;
```
