# App spec — `credentials`

Platform API credentials vault: Apple App Store Connect, Google Play, Shorebird, GitHub, GitLab, Bitbucket.

---

## 1. Models

### `Credential`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| provider | String | `apple` / `google_play` / `shorebird` / `github` / `gitlab` / `bitbucket` |
| name | String | human-readable label |
| encrypted_token | String | ciphertext |
| metadata | String | JSON non-secret metadata |
| expires_at | Option<DateTime<Utc>> | |
| last_used_at | Option<DateTime<Utc>> | |
| created_by_id | i64 | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

---

## 2. Contracts

### `CredentialCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct CredentialCreateRequest {
    pub provider: String,
    pub name: String,
    pub token: String, // plaintext in request
    pub metadata: CredentialMetadata,
    pub expires_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "provider")]
pub enum CredentialMetadata {
    Apple { key_id: String, issuer_id: String, team_id: String },
    GooglePlay { client_email: String },
    Shorebird { app_id: String },
    GitHub { installation_id: String },
    GitLab { application_id: String },
    Bitbucket { workspace: String },
}
```

### `CredentialResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct CredentialResponse {
    pub id: String,
    pub organization_id: String,
    pub provider: String,
    pub name: String,
    pub metadata: serde_json::Value,
    pub expires_at: Option<String>,
    pub last_used_at: Option<String>,
    pub created_at: String,
}
```

---

## 3. Services

### `create_credential(db, organization_id, user_id, req) -> Result<Credential, CredentialError>`

1. Encrypt token.
2. Validate metadata shape per provider.
3. Insert.
4. Emit `credential.created` event.

### `test_credential(db, credential) -> Result<(), CredentialError>`

Make a lightweight API call to the provider to verify credentials work. Do not store or log the token.

### `decrypt_for_worker(...)`

Internal endpoint for workers.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()` (but token never shown).
- `POST` / `DELETE` / `test` requires `OrganizationPermission::admin()`.

---

## 5. URLs

```rust
Router::new()
    .get("/credentials", views::list_credentials)
    .post("/credentials", views::create_credential)
    .get("/credentials/:id", views::retrieve_credential)
    .post("/credentials/:id/test", views::test_credential)
    .delete("/credentials/:id", views::delete_credential)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE credentials_credential (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    encrypted_token TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX credentials_credential_organization_id_idx ON credentials_credential(organization_id);

-- down
DROP TABLE credentials_credential;
```
