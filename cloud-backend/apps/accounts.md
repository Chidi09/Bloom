# App spec — `accounts`

The `accounts` app is the **golden app**. Every subsequent app copies its module boundaries, error mapping, repository/service split, route mounting, test layout, and migration style.

It handles authentication, API tokens, device-code login for the CLI, and the per-user profile.

---

## 1. Files

```text
src/apps/accounts/
├── mod.rs
├── models.rs
├── contracts.rs
├── serializers.rs
├── repositories.rs
├── services.rs
├── permissions.rs
├── views.rs
└── urls.rs

tests/apps/accounts/
├── models.rs
├── services.rs
├── permissions.rs
└── api.rs

migrations/accounts/0001_accounts.sql
```

---

## 2. Models

### `UserProfile`

Extends the Djangors built-in `djangors_auth::User` with Bloom Cloud-specific fields. One-to-one with `auth_user.id` on `user_id`.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal pk |
| public_id | String | UUID, exposed as `"id"` |
| user_id | i64 | FK to `djangors_auth::User.id` |
| display_name | String | optional |
| avatar_url | String | optional |
| timezone | String | default `UTC` |
| created_at | DateTime<Utc> | auto_now_add |
| updated_at | DateTime<Utc> | auto_now |

Unique on `user_id`.

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "accounts", table_name = "accounts_userprofile")]
pub struct UserProfile {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(unique)]
    pub user_id: i64,
    #[djangors(max_length = 36)]
    pub public_id: String,
    #[djangors(max_length = 255, nullable)]
    pub display_name: Option<String>,
    #[djangors(max_length = 500, nullable)]
    pub avatar_url: Option<String>,
    #[djangors(max_length = 64, default = "UTC")]
    pub timezone: String,
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[djangors(auto_now)]
    pub updated_at: chrono::DateTime<chrono::Utc>,
}
```

### `ApiToken`

Long-lived machine token for CI and integrations.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| user_id | ForeignKey<User> | |
| name | String | human-readable label |
| token_hash | String | sha256 of the raw token; only the raw token is shown once on creation |
| last_used_at | Option<DateTime<Utc>> | |
| created_at | DateTime<Utc> | |

### `DeviceFlowRequest`

Device-code flow for CLI login.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| device_code | String | unique, opaque |
| user_code | String | short human-entered code |
| status | String | `pending` / `authorized` / `expired` / `cancelled` |
| user_id | Option<ForeignKey<User>> | set on authorization |
| expires_at | DateTime<Utc> | |
| created_at | DateTime<Utc> | |

---

## 3. Contracts

### `RegisterRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub username: String,
    pub password: String,
}
```

### `LoginRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}
```

### `TokenResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i64,
}
```

### `DeviceFlowInitResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct DeviceFlowInitResponse {
    pub device_code: String,
    pub user_code: String,
    pub verification_uri: String,
    pub expires_in: i64,
    pub interval: i64,
}
```

### `MeResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct MeResponse {
    pub id: String,            // public_id
    pub email: String,
    pub username: String,
    pub display_name: Option<String>,
    pub avatar_url: Option<String>,
    pub timezone: String,
}
```

### `ApiTokenCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct ApiTokenCreateRequest {
    pub name: String,
}
```

### `ApiTokenResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct ApiTokenResponse {
    pub id: String,
    pub name: String,
    pub token: Option<String>, // only included on creation
    pub last_used_at: Option<String>,
    pub created_at: String,
}
```

---

## 4. Services

### `register_user(db, req) -> Result<(User, UserProfile), AccountError>`

1. Validate email uniqueness via `djangors_auth::User` queryset.
2. Validate username uniqueness.
3. Hash password with `djangors_auth::hash_password`.
4. Insert `User`.
5. Insert `UserProfile` with generated `public_id`.
6. Return both.

### `login_user(db, username, password, secret) -> Result<TokenResponse, AccountError>`

1. Use `djangors_auth::ModelBackend` to authenticate.
2. On success, issue JWT access + refresh tokens with `djangors_rest::encode_jwt`.
3. Return `TokenResponse`.

### `initiate_device_flow(db) -> Result<DeviceFlowInitResponse, AccountError>`

1. Generate `device_code` (opaque 40-char hex), `user_code` (8-char alphanumeric, readable).
2. Set `status = pending`, `expires_at = now + 10 minutes`.
3. Insert row.
4. Return response with verification URI.

### `poll_device_flow(db, device_code, secret) -> Result<TokenResponse, AccountError>`

1. Fetch request by `device_code`.
2. If expired, set `expired` and return error.
3. If `pending`, return error `authorization_pending`.
4. If `authorized`, issue JWT tokens for `user_id`.
5. Otherwise return error.

### `authorize_device_flow(db, device_code, user_id) -> Result<(), AccountError>`

Called by the browser dashboard after the user enters `user_code`. Sets `status = authorized`, `user_id`.

### `create_api_token(db, user_id, name) -> Result<(ApiToken, String), AccountError>`

1. Generate 64-char hex token.
2. Hash it with sha256 and store in `token_hash`.
3. Return model + raw token (raw token shown only once).

### `me(db, user_id) -> Result<MeResponse, AccountError>`

Fetch `UserProfile` by `user_id`, join with `djangors_auth::User` for email/username, return `MeResponse`.

---

## 5. Permissions

- `IsAuthenticated` from `djangors_rest` for all routes except device flow init/poll and webhooks.
- No organization scoping here; auth is global.
- A user can only revoke their own API tokens (superusers excepted).

---

## 6. Views & URLs

```rust
// src/apps/accounts/urls.rs
use djangors_core::Router;
use djangors_rest::AllowAny;

pub fn urls() -> Router {
    Router::new()
        .post("/auth/register", views::register)
        .post("/auth/login", views::login)
        .post("/auth/device", views::device_flow_init)
        .get("/auth/device/token", views::device_flow_poll)
        .post("/auth/device/authorize", views::device_flow_authorize)
        .post("/auth/token", views::create_api_token)
        .post("/auth/refresh", views::refresh_token)
        .get("/auth/me", views::me)
        .post("/auth/logout", views::logout)
}
```

Note: device flow init/poll use `AllowAny`. Authorization requires `IsAuthenticated`.

---

## 7. Error mapping

`AccountError` variants:

- `EmailTaken`
- `UsernameTaken`
- `InvalidCredentials`
- `DeviceCodeNotFound`
- `DeviceCodeExpired`
- `AuthorizationPending`
- `WeakPassword`
- `Database`

Map to:

| Variant | Status | Code |
|---------|--------|------|
| EmailTaken | 400 | email_taken |
| UsernameTaken | 400 | username_taken |
| InvalidCredentials | 401 | invalid_credentials |
| DeviceCodeNotFound | 404 | device_code_not_found |
| DeviceCodeExpired | 400 | device_code_expired |
| AuthorizationPending | 202 | authorization_pending |
| WeakPassword | 400 | weak_password |
| Database | 500 | database_error |

---

## 8. Tests

### Model tests

- `UserProfile` unique `user_id` constraint.
- `public_id` is generated as UUID.
- `ApiToken` `token_hash` uniqueness not required but lookup by hash works.

### Service tests

- Register with duplicate email fails.
- Login with correct credentials returns tokens.
- Login with wrong password fails with `invalid_credentials`.
- Device flow complete cycle: init → poll pending → authorize → poll success.
- Device flow expiry returns `device_code_expired`.
- API token raw value is shown once; subsequent retrieval does not include it.

### API tests

- `POST /api/v1/auth/register` returns 201 with user profile.
- `POST /api/v1/auth/login` returns tokens.
- `GET /api/v1/auth/me` requires auth and returns current user.
- `POST /api/v1/auth/logout` clears session.

---

## 9. Migration

```sql
-- up
CREATE TABLE accounts_userprofile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    display_name VARCHAR(255),
    avatar_url VARCHAR(500),
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE accounts_apitoken (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX accounts_apitoken_user_id_idx ON accounts_apitoken(user_id);

CREATE TABLE accounts_deviceflowrequest (
    id BIGSERIAL PRIMARY KEY,
    device_code VARCHAR(80) NOT NULL UNIQUE,
    user_code VARCHAR(16) NOT NULL,
    status VARCHAR(32) NOT NULL,
    user_id BIGINT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX accounts_deviceflowrequest_user_code_idx ON accounts_deviceflowrequest(user_code);
CREATE INDEX accounts_deviceflowrequest_expires_at_idx ON accounts_deviceflowrequest(expires_at);

-- down
DROP TABLE accounts_deviceflowrequest;
DROP TABLE accounts_apitoken;
DROP TABLE accounts_userprofile;
```

---

## 10. Integration notes

- This app does **not** implement organization scoping. It is global identity.
- The `CurrentUserId` extension is set by auth middleware and consumed by organization resolution.
- Password hashing reuses `djangors_auth::hash_password` / `verify_password` (Argon2id).
