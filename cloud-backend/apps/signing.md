# App spec — `signing`

Encrypted signing material storage: Android keystores, iOS certificates, provisioning profiles, App Store Connect API keys.

---

## 1. Models

### `SigningIdentity`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| platform | String | `android` / `ios` |
| name | String | |
| kind | String | `keystore` / `certificate` / `provisioning_profile` / `api_key` |
| encrypted_material | String | ciphertext bytes (base64) |
| metadata | String | JSON fingerprints, bundle IDs, expiry, team ID, etc. |
| expires_at | Option<DateTime<Utc>> | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

---

## 2. Contracts

### `SigningIdentityCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct SigningIdentityCreateRequest {
    pub platform: String,
    pub name: String,
    pub kind: String,
    pub material: String, // base64-encoded file content
    pub metadata: SigningIdentityMetadata,
    pub expires_at: Option<String>,
}
```

### `SigningIdentityMetadata`

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum SigningIdentityMetadata {
    Keystore { alias: String },
    Certificate { fingerprint: String },
    ProvisioningProfile { bundle_id: String, uuid: String },
    ApiKey { key_id: String, issuer_id: String, team_id: String },
}
```

### `SigningIdentityResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct SigningIdentityResponse {
    pub id: String,
    pub organization_id: String,
    pub platform: String,
    pub name: String,
    pub kind: String,
    pub metadata: serde_json::Value,
    pub expires_at: Option<String>,
    pub created_at: String,
}
```

---

## 3. Services

### `upload_signing_identity(db, organization_id, user_id, req) -> Result<SigningIdentity, SigningError>`

1. Encrypt base64 material.
2. Parse metadata and extract expiry where possible.
3. Insert.
4. Emit `signing.created` event.

### `decrypt_for_worker(...)`

Internal endpoint for workers to fetch decrypted material.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` / `DELETE` requires `OrganizationPermission::release_manager()`.

---

## 5. URLs

```rust
Router::new()
    .get("/signing", views::list_signing_identities)
    .post("/signing", views::upload_signing_identity)
    .get("/signing/:id", views::retrieve_signing_identity)
    .delete("/signing/:id", views::delete_signing_identity)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE signing_signingidentity (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    encrypted_material TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX signing_signingidentity_organization_id_idx ON signing_signingidentity(organization_id);

-- down
DROP TABLE signing_signingidentity;
```
