# App spec — `apps`

The `apps` app represents a Bloom application within a project. One app can have multiple platforms (iOS, Android, Web) and environments.

---

## 1. Models

### `App`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| project_id | ForeignKey<Project> | |
| name | String | |
| slug | String | unique per project |
| repository_url | String | optional Git URL |
| default_branch | String | default `main` |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(project_id, slug)`.

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "apps", table_name = "apps_app")]
pub struct App {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(max_length = 36)]
    pub public_id: String,
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub project_id: djangors_orm::ForeignKey<crate::apps::projects::models::Project>,
    #[djangors(max_length = 255)]
    pub name: String,
    #[djangors(max_length = 64)]
    pub slug: String,
    #[djangors(max_length = 500, nullable)]
    pub repository_url: Option<String>,
    #[djangors(max_length = 255, default = "main")]
    pub default_branch: String,
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[djangors(auto_now)]
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl djangors_rest::Scoped for App {
    fn scope(req: &djangors_core::Request, qs: djangors_orm::QuerySet<Self>) -> Result<QuerySet<Self>, djangors_core::DjangorsError> {
        // App is scoped through project -> organization.
        // This requires a join or denormalized org id.
        // For simplicity, store organization_id on App as well (denormalized).
        crate::apps::organizations::scoping::organization_scope(req, qs, "organization_id")
    }
}
```

**Decision**: Denormalize `organization_id` on `App` for direct scoping. Keep it in sync on insert/update via service layer. Alternatively, use a subquery through `Project`. The denormalized approach is simpler and matches the school-management SaaS pattern.

Add `organization_id: i64` to the model.

---

## 2. Contracts

### `AppCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct AppCreateRequest {
    pub project_id: String, // public UUID
    pub name: String,
    pub repository_url: Option<String>,
    pub default_branch: Option<String>,
}
```

### `AppUpdateRequest`

```rust
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct AppUpdateRequest {
    pub name: Option<String>,
    pub repository_url: Option<String>,
    pub default_branch: Option<String>,
}
```

### `AppLinkRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct AppLinkRequest {
    pub project_slug: String,
    pub app_slug: String,
}
```

### `AppResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct AppResponse {
    pub id: String,
    pub project_id: String,
    pub organization_id: String,
    pub name: String,
    pub slug: String,
    pub repository_url: Option<String>,
    pub default_branch: String,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 3. Services

### `create_app(db, organization_id, req) -> Result<App, AppError>`

1. Resolve `project_id` from public UUID.
2. Verify project belongs to organization.
3. Generate slug from name.
4. Insert `App` with `organization_id` denormalized.
5. Emit `app.created` event.

### `link_app(db, organization_id, req) -> Result<App, AppError>`

CLI helper: look up by `project_slug` and `app_slug` within organization.

### `delete_app(db, app) -> Result<(), AppError>`

Refuse if app has environments/builds/releases.

---

## 4. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` requires `OrganizationPermission::developer()`.
- `PATCH`/`DELETE` requires `OrganizationPermission::developer()`.

---

## 5. URLs

```rust
Router::new()
    .get("/apps", views::list_apps)
    .post("/apps", views::create_app)
    .post("/apps/link", views::link_app)
    .get("/apps/:id", views::retrieve_app)
    .patch("/apps/:id", views::update_app)
    .delete("/apps/:id", views::delete_app)
```

---

## 6. Migration

```sql
-- up
CREATE TABLE apps_app (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    project_id BIGINT NOT NULL REFERENCES projects_project(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    repository_url VARCHAR(500),
    default_branch VARCHAR(255) NOT NULL DEFAULT 'main',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(project_id, slug)
);

CREATE INDEX apps_app_project_id_idx ON apps_app(project_id);
CREATE INDEX apps_app_organization_id_idx ON apps_app(organization_id);

-- down
DROP TABLE apps_app;
```
