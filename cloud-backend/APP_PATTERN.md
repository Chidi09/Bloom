# Djangors domain-app pattern — Bloom Cloud

This is the required shape for every domain app in the Bloom Cloud backend. A domain app is accepted only when it follows this structure, keeps business rules out of HTTP handlers, and passes centralized tests and contract checks.

## App layout

```text
src/apps/<app>/
├── mod.rs            # public module surface and app wiring
├── models.rs         # #[derive(Model)] persistence models
├── contracts.rs      # request/query/path and response DTOs
├── serializers.rs    # Djangors Serializer / ModelSerializer adapters
├── repositories.rs   # QuerySet/database access only
├── services.rs       # transactions and business rules
├── permissions.rs    # Djangors permission composition and org/project checks
├── views.rs          # async Request -> Response handlers
├── urls.rs           # app-local Router
└── admin.rs          # only when admin registration is needed

tests/apps/<app>/
├── models.rs         # model metadata and constraint tests
├── services.rs       # business-rule tests
├── permissions.rs    # role and tenant-isolation tests
└── api.rs            # real request/response contract tests

migrations/<app>/NNNN_<app>.sql
```

All tests belong under `tests/`. Production files under `src/` must contain no `#[cfg(test)]`, `#[test]`, or `#[tokio::test]` blocks.

## Dependency flow

```text
urls -> views -> permissions/contracts/services -> repositories -> Djangors ORM/DB
```

- `urls.rs` only registers routes and mounts handlers.
- `views.rs` extracts input, invokes permissions/services, and maps results to responses. It contains no business rules and no SQL.
- `contracts.rs` owns request, query, path, and response shapes. Do not expose database rows directly when the API has a different wire shape.
- `serializers.rs` owns validation, field visibility, and representation.
- `services.rs` owns transactions, state transitions, cross-record checks, and domain errors.
- `repositories.rs` owns QuerySet construction and database reads/writes. It never creates HTTP responses and never decides role permissions.
- Apps may call another app only through that app's public service interface; they may not import another app's repository or private model internals.
- `mod.rs` exports only the app's public service functions and `urls()`.
- The root `src/apps/mod.rs` is the only domain-route composition point. It is mounted once by `src/urls.rs` at `/api/v1` with `Router::mount`.

## Djangors-native persistence contract

Use the APIs Djangors is designed to provide:

- `#[derive(Model)]` from `djangors-macros`.
- `QuerySet`, `q!`, `ForeignKey<T>`, and `Database` from Djangors ORM/DB.
- `ModelSerializer` or a custom `Serializer` from `djangors-rest`.
- Djangors permissions, pagination, throttling, OpenAPI, admin, and migration facilities wherever their actual `0.7.0` APIs support the requirement.
- `#[task]` / `enqueue` / `Worker` from `djangors-tasks` for background side effects (emails, webhook async processing, audit cleanup, platform polling).
- `#[derive(Settings)]` from `djangors-macros` for application-specific typed configuration.

All direct Djangors dependencies are pinned to exactly `=0.7.0`.

## Compatibility rules for this backend

- Internal `i64` auto-increment primary keys and `ForeignKey<T>` relations for native Djangors models.
- Where the API requires UUID identifiers, keep the unique `public_id: String` and expose that through contracts/serializers. Never leak an internal key accidentally.
- Date-only/time-only values may use `NaiveDate`/`NaiveTime` natively.
- Store money as integer minor units (`amount_cents: i64`); never use a floating-point amount.
- Store JSON columns only behind a typed contract conversion. A string-backed JSON column must be parsed and validated in the service/serializer boundary.
- Use `djangors-contrib-tenancy` only where a model is genuinely tenant-scoped. Bloom Cloud is **organization-scoped**, not tenant-scoped in the school-SaaS sense. The organization scoping uses the same `Scoped` trait pattern but with a custom `organization_scope` helper.

## Required app checklist

Before an app is considered complete, its implementation must include:

- An exact inventory of the model fields, relations, choices, constraints, indexes, `on_delete` rules, URLs, status codes, and permissions.
- `models.rs` metadata that compiles against Djangors `0.7.0`.
- A reversible `migrations/<app>/NNNN_<app>.sql` with explicit `-- up` and `-- down` sections.
- Organization/project filtering on every scoped read and write.
- A role/permission matrix and tests for allowed, denied, and cross-organization requests.
- Exact API error envelope, pagination, filters, ordering, and response-shape parity with the spec.
- Service tests, model/constraint tests, permission tests, and API tests under `tests/apps/<app>/`; no tests in `src/`.
- `cargo fmt --check`, `cargo check`, `cargo test`, `cargo clippy --all-targets -- -D warnings` passing.

## Golden-app rule

The first migrated app (`accounts`) is the reference implementation. Later apps must copy its module boundaries, error mapping, repository/service split, route mounting, test layout, and migration style. Improvements to the pattern must be made in the golden app and this document first, then propagated deliberately.

## Organization scoping helper

Because Bloom Cloud scopes by organization rather than by `djangors-contrib-tenancy::Tenant`, each scoped app implements `Scoped` with a shared helper:

```rust
// src/apps/common/scoping.rs
use djangors_core::{Request, error::DjangorsError};
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

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
        .get::<crate::apps::accounts::CurrentOrganizationId>()
        .ok_or_else(|| DjangorsError::api(StatusCode::FORBIDDEN, "organization_required", "No organization selected."))?
        .0;
    qs.filter(djangors_orm::q!(field = org_id))
        .map_err(|e| DjangorsError::Internal(e.to_string()))
}
```

Models with an `organization_id: i64` column use it like this:

```rust
impl Scoped for Project {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
```

`CurrentOrganizationId` is set by an `OrganizationResolutionLayer` middleware after auth. It is the single source of truth for which organization the request is operating on.
