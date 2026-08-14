# App spec — `environments`

An environment holds configuration, secrets, build defaults, and deployment targets for an app. Common: `development`, `staging`, `production`.

---

## 1. Models

### `Environment`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| organization_id | i64 | denormalized for scoping |
| name | String | e.g. `production` |
| slug | String | unique per app |
| api_config | String | JSON text of env vars + feature flags |
| build_profile | String | `debug` / `profile` / `release` |
| flutter_version | String | optional pinned Flutter version |
| dart_version | String | optional pinned Dart version |
| bloom_version | String | optional pinned Bloom CLI version |
| flavor | String | optional |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(app_id, slug)`.

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "environments", table_name = "environments_environment")]
pub struct Environment {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(max_length = 36)]
    pub public_id: String,
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub app_id: djangors_orm::ForeignKey<crate::apps::apps::models::App>,
    pub organization_id: i64,
    #[djangors(max_length = 255)]
    pub name: String,
    #[djangors(max_length = 64)]
    pub slug: String,
    pub api_config: String, // JSON
    #[djangors(max_length = 32, default = "release")]
    pub build_profile: String,
    #[djangors(max_length = 64, nullable)]
    pub flutter_version: Option<String>,
    #[djangors(max_length = 64, nullable)]
    pub dart_version: Option<String>,
    #[djangors(max_length = 64, nullable)]
    pub bloom_version: Option<String>,
    #[djangors(max_length = 64, nullable)]
    pub flavor: Option<String>,
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[djangors(auto_now)]
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl djangors_rest::Scoped for Environment {
    fn scope(req: &djangors_core::Request, qs: djangors_orm::QuerySet<Self>) -> Result<QuerySet<Self>, djangors_core::DjangorsError> {
        crate::apps::organizations::scoping::organization_scope(req, qs, "organization_id")
    }
}
```

### `ApiConfig` typed contract

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiConfig {
    pub env_vars: Vec<EnvVar>,
    pub feature_flags: Vec<FeatureFlag>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnvVar {
    pub key: String,
    pub value: String, // this is the *declared* value, not a secret
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureFlag {
    pub key: String,
    pub enabled: bool,
}
```

The `api_config` JSON stores non-secret values. Actual secrets live in the `secrets` app.

---

## 2. Contracts

### `EnvironmentCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct EnvironmentCreateRequest {
    pub app_id: String,
    pub name: String,
    pub slug: String,
    pub api_config: ApiConfig,
    pub build_profile: Option<String>,
    pub flutter_version: Option<String>,
    pub dart_version: Option<String>,
    pub bloom_version: Option<String>,
    pub flavor: Option<String>,
}
```

### `EnvironmentUpdateRequest`

```rust
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct EnvironmentUpdateRequest {
    pub name: Option<String>,
    pub api_config: Option<ApiConfig>,
    pub build_profile: Option<String>,
    pub flutter_version: Option<String>,
    pub dart_version: Option<String>,
    pub bloom_version: Option<String>,
    pub flavor: Option<String>,
}
```

### `EnvironmentResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct EnvironmentResponse {
    pub id: String,
    pub app_id: String,
    pub organization_id: String,
    pub name: String,
    pub slug: String,
    pub api_config: ApiConfig,
    pub build_profile: String,
    pub flutter_version: Option<String>,
    pub dart_version: Option<String>,
    pub bloom_version: Option<String>,
    pub flavor: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 3. Services

### `create_environment(db, organization_id, req) -> Result<Environment, EnvironmentError>`

1. Resolve `app_id` and verify it belongs to organization.
2. Validate slug uniqueness per app.
3. Validate `api_config` JSON shape.
4. Insert.
5. Emit `environment.created` event.

### `get_effective_build_config(env, secrets) -> BuildConfig`

Merges environment defaults with secrets to produce the full env that a build worker receives. This is computed at worker job time, not stored.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST`/`PATCH`/`DELETE` requires `OrganizationPermission::developer()`.

---

## 5. URLs

```rust
Router::new()
    .get("/environments", views::list_environments)
    .post("/environments", views::create_environment)
    .get("/environments/:id", views::retrieve_environment)
    .patch("/environments/:id", views::update_environment)
    .delete("/environments/:id", views::delete_environment)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE environments_environment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    api_config TEXT NOT NULL DEFAULT '{}',
    build_profile VARCHAR(32) NOT NULL DEFAULT 'release',
    flutter_version VARCHAR(64),
    dart_version VARCHAR(64),
    bloom_version VARCHAR(64),
    flavor VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, slug)
);

CREATE INDEX environments_environment_app_id_idx ON environments_environment(app_id);
CREATE INDEX environments_environment_organization_id_idx ON environments_environment(organization_id);

-- down
DROP TABLE environments_environment;
```
