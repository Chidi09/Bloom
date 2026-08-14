# App spec — `organizations`

The `organizations` app defines the billing and membership boundary for Bloom Cloud. Every other app is scoped to an organization (and usually to a project/app/environment within it).

---

## 1. Files

```text
src/apps/organizations/
├── mod.rs
├── models.rs
├── contracts.rs
├── serializers.rs
├── repositories.rs
├── services.rs
├── permissions.rs
├── views.rs
└── urls.rs

tests/apps/organizations/
├── models.rs
├── services.rs
├── permissions.rs
└── api.rs

migrations/organizations/0001_organizations.sql
```

---

## 2. Models

### `Organization`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID, exposed as `"id"` |
| name | String | max 255 |
| slug | String | unique, URL-safe, max 64 |
| plan | String | `free` / `pro` / `enterprise` |
| billing_email | String | optional |
| created_at | DateTime<Utc> | auto_now_add |
| updated_at | DateTime<Utc> | auto_now |

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "organizations", table_name = "organizations_organization")]
pub struct Organization {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(max_length = 36)]
    pub public_id: String,
    #[djangors(max_length = 255)]
    pub name: String,
    #[djangors(max_length = 64, unique)]
    pub slug: String,
    #[djangors(max_length = 32, default = "free")]
    pub plan: String,
    #[djangors(max_length = 254, nullable)]
    pub billing_email: Option<String>,
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[djangors(auto_now)]
    pub updated_at: chrono::DateTime<chrono::Utc>,
}
```

### `UserOrganizationMembership`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| user_id | i64 | FK to auth_user |
| organization_id | ForeignKey<Organization> | |
| role | String | `owner` / `admin` / `developer` / `release_manager` / `viewer` |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(user_id, organization_id)`.

### `OrganizationInvite`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| email | String | invitee email |
| role | String | |
| token | String | secure random token |
| expires_at | DateTime<Utc> | |
| accepted_at | Option<DateTime<Utc>> | |
| created_at | DateTime<Utc> | |

---

## 3. Contracts

### `OrganizationCreateRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct OrganizationCreateRequest {
    pub name: String,
}
```

### `OrganizationUpdateRequest`

```rust
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct OrganizationUpdateRequest {
    pub name: Option<String>,
    pub billing_email: Option<String>,
}
```

### `OrganizationResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct OrganizationResponse {
    pub id: String,
    pub name: String,
    pub slug: String,
    pub plan: String,
    pub role: String, // current user's role in this org
    pub created_at: String,
}
```

### `MembershipResponse`

```rust
#[derive(Debug, Clone, Serialize)]
pub struct MembershipResponse {
    pub id: String,
    pub user_id: String,
    pub email: String,
    pub username: String,
    pub role: String,
    pub created_at: String,
}
```

### `InviteRequest`

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct InviteRequest {
    pub email: String,
    pub role: String,
}
```

---

## 4. Services

### `create_organization(db, user_id, name) -> Result<Organization, OrganizationError>`

1. Generate slug from name (deduplicate if taken).
2. Insert `Organization`.
3. Insert `UserOrganizationMembership` with role `owner`.
4. Return organization.

### `update_organization(db, org_id, req) -> Result<Organization, OrganizationError>`

Validate fields, update row, return updated organization.

### `delete_organization(db, org_id) -> Result<(), OrganizationError>`

Only `owner` can delete. Hard delete only if no projects/apps exist; otherwise return `organization_not_empty`.

### `add_member(db, org_id, email, role) -> Result<OrganizationInvite, OrganizationError>`

1. Validate email is not already a member.
2. Generate secure invite token.
3. Insert `OrganizationInvite`.
4. Send invite email (deferred to `djangors-mail`; for tests use in-memory backend).

### `accept_invite(db, token, user_id) -> Result<UserOrganizationMembership, OrganizationError>`

1. Fetch invite by token.
2. Check not expired and not already accepted.
3. Create membership.
4. Mark invite accepted.

### `change_member_role(db, org_id, membership_id, new_role) -> Result<(), OrganizationError>`

Only `owner` and `admin` can change roles. `owner` role can only be changed by another `owner`. At least one owner must remain.

### `remove_member(db, org_id, membership_id) -> Result<(), OrganizationError>`

Cannot remove the last owner.

### `resolve_organization_for_user(db, user_id, org_public_id) -> Result<OrganizationMembership, OrganizationError>`

Validate the user is a member and return the organization + role.

---

## 5. Permissions

Implement `OrganizationPermission`:

```rust
pub struct OrganizationPermission {
    pub min_role: OrganizationRole,
}

impl djangors_rest::Permission for OrganizationPermission {
    async fn has_permission(&self, req: &Request) -> bool {
        // 1. request must be authenticated
        // 2. CurrentOrganizationId must exist
        // 3. user's membership role must be >= min_role
    }
}
```

Role ordering: `viewer < developer < release_manager < admin < owner`.

Convenience constructors:

- `OrganizationPermission::viewer()`
- `OrganizationPermission::developer()`
- `OrganizationPermission::release_manager()`
- `OrganizationPermission::admin()`
- `OrganizationPermission::owner()`

Also export `OrganizationRole` enum and helper to check role at least.

---

## 6. Middleware — OrganizationResolutionLayer

Sets `CurrentOrganizationId(i64)` in request extensions.

1. Read `X-Bloom-Organization-Id` header (public UUID).
2. Look up organization by `public_id`.
3. Fetch `UserOrganizationMembership` for `current_user.id` + organization.id.
4. If found, set `CurrentOrganizationId(organization.id)` and `CurrentOrganizationRole(role)`.
5. If not found, do **not** set the extension; scoped endpoints will fail closed with 403.

---

## 7. Views & URLs

```rust
pub fn urls() -> Router {
    Router::new()
        .get("/organizations", views::list_organizations)
        .post("/organizations", views::create_organization)
        .get("/organizations/current", views::current_organization)
        .get("/organizations/:id", views::retrieve_organization)
        .patch("/organizations/:id", views::update_organization)
        .delete("/organizations/:id", views::delete_organization)
        .get("/organizations/:id/members", views::list_members)
        .post("/organizations/:id/members", views::invite_member)
        .patch("/organizations/:id/members/:member_id", views::change_role)
        .delete("/organizations/:id/members/:member_id", views::remove_member)
        .post("/organizations/invites/accept", views::accept_invite)
}
```

Use `PathParams` to extract `:id` and `:member_id` (public UUIDs).

---

## 8. Scoping helper

This app exports the shared scoping helper used by other apps.

```rust
// src/apps/organizations/scoping.rs
use djangors_core::{Request, error::DjangorsError, StatusCode};
use djangors_orm::QuerySet;

#[derive(Clone, Copy, Debug)]
pub struct CurrentOrganizationId(pub i64);

#[derive(Clone, Debug)]
pub struct CurrentOrganizationRole(pub String);

pub fn organization_scope<M>(
    req: &Request,
    qs: QuerySet<M>,
    field: &str,
) -> Result<QuerySet<M>, DjangorsError>
where
    M: djangors_orm::Model,
{
    let org_id = req
        .extensions()
        .get::<CurrentOrganizationId>()
        .ok_or_else(|| {
            DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            )
        })?
        .0;
    qs.filter(djangors_orm::q!(field = org_id))
        .map_err(|e| DjangorsError::Internal(e.to_string()))
}
```

---

## 9. Error mapping

| Variant | Status | Code |
|---------|--------|------|
| NameTaken | 400 | name_taken |
| SlugTaken | 400 | slug_taken |
| OrganizationNotFound | 404 | organization_not_found |
| MembershipNotFound | 404 | membership_not_found |
| AlreadyMember | 400 | already_member |
| InviteNotFound | 404 | invite_not_found |
| InviteExpired | 400 | invite_expired |
| CannotRemoveLastOwner | 400 | cannot_remove_last_owner |
| OrganizationNotEmpty | 400 | organization_not_empty |
| InsufficientRole | 403 | insufficient_role |

---

## 10. Tests

### Model tests

- Slug uniqueness.
- Membership unique together `(user_id, organization_id)`.
- Invite token uniqueness.

### Service tests

- Create org sets creator as owner.
- Member cannot delete org.
- Removing last owner fails.
- Accepting invite creates membership.
- Expired invite cannot be accepted.

### Permission tests

- Viewer cannot create project.
- Developer cannot manage billing/members.
- Owner can delete org (if empty).
- Cross-org access returns 403.

### API tests

- `GET /api/v1/organizations` lists user's orgs.
- `POST /api/v1/organizations` creates org and membership.
- `PATCH /api/v1/organizations/:id` requires admin+.
- `DELETE /api/v1/organizations/:id` requires owner and empty org.

---

## 11. Migration

```sql
-- up
CREATE TABLE organizations_organization (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL UNIQUE,
    plan VARCHAR(32) NOT NULL DEFAULT 'free',
    billing_email VARCHAR(254),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE organizations_userorganizationmembership (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, organization_id)
);

CREATE INDEX organizations_membership_org_id_idx ON organizations_userorganizationmembership(organization_id);
CREATE INDEX organizations_membership_user_id_idx ON organizations_userorganizationmembership(user_id);

CREATE TABLE organizations_organizationinvite (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    email VARCHAR(254) NOT NULL,
    role VARCHAR(32) NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX organizations_invite_token_idx ON organizations_organizationinvite(token);
CREATE INDEX organizations_invite_org_id_idx ON organizations_organizationinvite(organization_id);

-- down
DROP TABLE organizations_organizationinvite;
DROP TABLE organizations_userorganizationmembership;
DROP TABLE organizations_organization;
```

---

## 12. Notes

- Organization slug generation: lower-case, replace spaces/special chars with `-`, truncate to 64, append number if collision.
- The middleware must run after auth so `current_user` is available.
- `X-Bloom-Organization-Id` is required by every scoped endpoint; unscoped endpoints (like listing all orgs) ignore it.
