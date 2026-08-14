# App spec — `projects`

A project groups Bloom applications within an organization. Usually one project per product (e.g., "My SaaS").

---

## 1. Files

```text
src/apps/projects/
├── mod.rs
├── models.rs
├── contracts.rs
├── serializers.rs
├── repositories.rs
├── services.rs
├── permissions.rs
├── views.rs
└── urls.rs

tests/apps/projects/
├── models.rs
├── services.rs
├── permissions.rs
└── api.rs

migrations/projects/0001_projects.sql
```

---

## 2. Models

### `Project`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| name | String | max 255 |
| slug | String | unique per organization |
| description | String | optional |
| created_at | DateTime<Utc> | auto_now_add |
| updated_at | DateTime<Utc> | auto_now |

Unique together: `(organization_id, slug)`.

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "projects", table_name = "projects_project")]
pub struct Project {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(max_length = 36)]
    pub public_id: String,
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: djangors_orm::ForeignKey<crate::apps::organizations::models::Organization>,
    #[djangors(max_length = 255)]
    pub name: String,
    #[djangors(max_length = 64)]
    pub slug: String,
    #[djangors(max_length = 1000, nullable)]
    pub description: Option<String>,
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[djangors(auto_now)]
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl djangors_rest::Scoped for Project {
    fn scope(req: &djangors_core::Request, qs: djangors_orm::QuerySet<Self>) -> Result<QuerySet<Self>, djangors_core::DjangorsError> {
        crate::apps::organizations::scoping::organization_scope(req, qs, "organization_id")
    }
}
```

---

## 3. Contracts

### `ProjectCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct ProjectCreateRequest {
    pub name: String,
    pub description: Option<String>,
}
```

### `ProjectUpdateRequest`

```rust
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct ProjectUpdateRequest {
    pub name: Option<String>,
    pub description: Option<String>,
}
```

### `ProjectResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct ProjectResponse {
    pub id: String,
    pub organization_id: String,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}
```

---

## 4. Services

### `create_project(db, organization_id, req) -> Result<Project, ProjectError>`

1. Generate slug from name.
2. Ensure `(organization_id, slug)` is unique.
3. Insert `Project`.
4. Emit `project.created` event.

### `update_project(db, project, req) -> Result<Project, ProjectError>`

1. Apply partial update.
2. If name changed and slug not explicitly provided, regenerate slug.
3. Emit `project.updated` event.

### `delete_project(db, project) -> Result<(), ProjectError>`

1. Refuse if project has apps (return `project_not_empty`).
2. Delete.
3. Emit `project.deleted` event.

### `list_projects_for_organization(db, organization_id) -> Result<Vec<Project>, ProjectError>`

Filter by `organization_id`, default ordering by `-created_at`.

---

## 5. Permissions

- `GET` requires `OrganizationPermission::viewer()`.
- `POST` requires `OrganizationPermission::admin()`.
- `PATCH`/`DELETE` on a project requires `OrganizationPermission::admin()`.

All endpoints use `Scoped` so cross-organization projects are invisible.

---

## 6. Views & URLs

```rust
pub fn urls() -> Router {
    Router::new()
        .get("/projects", views::list_projects)
        .post("/projects", views::create_project)
        .get("/projects/:id", views::retrieve_project)
        .patch("/projects/:id", views::update_project)
        .delete("/projects/:id", views::delete_project)
}
```

---

## 7. Tests

- Slug uniqueness per organization.
- Two organizations can have the same project slug.
- Viewer can list but not create.
- Cannot delete project with apps.
- Cross-org project is 404.

---

## 8. Migration

```sql
-- up
CREATE TABLE projects_project (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, slug)
);

CREATE INDEX projects_project_org_id_idx ON projects_project(organization_id);

-- down
DROP TABLE projects_project;
```
