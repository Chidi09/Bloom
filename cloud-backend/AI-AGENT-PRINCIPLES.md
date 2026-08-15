# Read this before touching Bloom Cloud backend

This document is written for an AI agent picking up work on the Bloom Cloud backend — possibly with no memory of prior sessions. Read it in full before writing any code. It is not a style guide. It is a correction of the single most common and most expensive mistake made while building on Djangors: **inventing a pattern instead of finding the one that already exists.**

## The one rule everything else follows from

**Bloom Cloud backend is built on Djangors `=0.7.0`. Every pattern has a real, working Djangors equivalent.** If you ever think "Djangors doesn't have X, so I'll hand-roll a workaround," you are almost certainly wrong. Stop and go find X.

The framework ships: ORM with `QuerySet`/`q!`, migrations, admin, auth, permissions, REST framework with ViewSets/serializers/pagination/throttling/filtering, caching, background tasks via `#[task]`/`Worker`/`enqueue`, multi-tenancy, typed settings via `#[derive(Settings)]`, logging, dual Postgres/SQLite backend, and more. Read the real source before calling any API you are not already certain about.

## The workflow, every time

1. **Read the relevant specification in this directory first.** `DESIGN-SPEC.md` is the master; `apps/<app>.md` is the per-app contract; `integrations/<platform>.md` is the external API contract. Do not guess scope.
2. **Before writing a single line of new Rust for a mechanism** (pagination, caching, a permission check, a transaction, rate limiting, a validation error shape, filtering, an audit log, a signal, a background task, typed settings), search `djangors-contrib` and the pinned `0.7.0` crate source.

   **The authoritative source is the Djangors monorepo checked out on this machine at `/root/dev/Rango/crates/djangors-*/src/` (git tag `v0.7.0`).** Read it there. It is the exact pinned version, it is complete, and it needs no network. A registry copy may also exist under `/root/.cargo/registry/src/index.crates.io-*/djangors-<crate>-0.7.0/src/`, but prefer the monorepo — the registry cache has at times held only older versions.

   **Working reference implementation:** `/root/dev/school-management-saas-/backend` is a large, real Djangors codebase (60+ domain apps) whose `src/apps/accounts/` follows this project's required app layout. Read it for *patterns* — module boundaries, repository/service split, error mapping, permission composition, migration style. **But it is pinned `=0.6.3`, not `0.7.0`.** Never copy a call site from it without confirming the signature against `/root/dev/Rango/crates/`.
3. **Verify the exact API by reading the real crate source**, not by inference from the docs. Every "fabricated API" bug comes from writing code against a guessed API instead of the real one. Guessing is not allowed.
4. **Follow the file layout in `APP_PATTERN.md`.** It exists because it is the required Djangors domain-app structure. Do not improvise a different split for one app "because it's simpler here."
5. **Use the exact public-identifier convention.** Every model has an internal `i64` primary key that never crosses the API boundary, and a `public_id: String` (UUID) that does. Every JSON response keys the public identity as `"id"`, never `"public_id"`. Every foreign key crosses the wire as the related row's UUID string.
6. **Verify, then verify again as an outsider.** `cargo check`, `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, and `cargo test` passing means the Rust compiles. It does **not** mean it matches the spec. Re-read the spec side by side with what you wrote and check every model field, every status code, every permission boundary, every event name.

## Wire contract (non-negotiable, applies to every app)

- Internal primary keys (`i64`) never cross the API boundary.
- `public_id: String` (UUID v4) is exposed as `"id"` in JSON.
- Foreign keys are exposed as related UUID strings in both requests and responses.
- Money, where it exists (billing), is integer minor units (`amount_cents: i64`), never float/Decimal.
- Status fields use uppercase `Snake_Case` strings over the wire exactly as defined in the model choices.
- Error responses use the Djangors `DjangorsError::api(status, code, message)` shape with optional `details`.
- Every tenant-scoped or organization-scoped model uses `Scoped` with `tenant_scope` or an organization-scoped equivalent. There is no un-scoped escape hatch.

## Verified API facts (save yourself the rediscovery)

**Read this caveat before trusting the list below.** The facts in this section were originally established by reading the real `=0.6.3` source, but this project pins `=0.7.0`. They are a strong starting point, not gospel: confirm each one against `/root/dev/Rango/crates/` before you rely on it, and re-verify anything not on this list.

### Re-verified against the pinned 0.7.0 source

These were each confirmed by reading `/root/dev/Rango/crates/` at tag `v0.7.0`, with the file and line where the signature lives:

- **Project bootstrap** — the canonical `main.rs` sequence is, in this exact order: `djangors_core::introspect_models_if_requested()`, `djangors_core::run_management_command_if_requested().await`, `djangors_core::logging::init_dev_logging()`, `DjangorsSettings::load()?` (returns `(settings, warnings)`), build `Router`, `djangors_core::router::RouterService::new(router, settings.debug)`, wrap in `tower::ServiceBuilder` with `djangors_core::middleware::security_headers_layer()`, then `Djangors::new(settings, Router::new()).run_service(service).await`. Source: `djangors-cli/src/commands.rs` (the framework's own generator).
- **Handler signature is two arguments**: `async fn name(req: Request, params: PathParams) -> Result<Response, DjangorsError>`. Easy to get wrong — a one-argument handler will not compile.
- `Response::html(StatusCode, String)` and `Response::text(StatusCode, &str)`.
- `djangors_db::DatabaseConfig::new(url: impl Into<String>) -> Self` — `djangors-db/src/config.rs:27`.
- `djangors_db::Database::connect(config: &DatabaseConfig) -> Result<Self, DbError>` (async) — `djangors-db/src/database.rs:62`.
- `Router::with_state<T: Send + Sync + 'static>(self, value: T) -> Self` — `djangors-core/src/router.rs:125`. Chainable; call once per state type.
- `DjangorsError::Internal(String)` is a real variant — `djangors-core/src/error.rs:83`.
- `DjangorsError::api(status: StatusCode, code: impl Into<String>, message: impl Into<String>)` — `djangors-core/src/error.rs:125`.
- `djangors_migrations::migrate(db: &Database) -> Result<(), MigrationError>` — `djangors-migrations/src/lib.rs:210`.
- `djangors_migrations::migrate_from_dir(db: &Database, dir: &Path) -> Result<(), MigrationError>` — `djangors-migrations/src/lib.rs:37`. `MigrationError` is re-exported from the crate root.
- `djangors_rest::current_user(req: &Request) -> Option<djangors_auth::User>` (async) — `djangors-rest/src/permissions.rs:53`. Note the return type is `djangors_auth::User`.
- `djangors_rest::Scoped` is `trait Scoped: Model + FromRow + Send + Sync + 'static` with `fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError>` — `djangors-rest/src/viewsets.rs:265`. Your model must satisfy the `FromRow` bound too.
- Pagination types all exist in `djangors-rest/src/pagination.rs`: `PageNumberPagination` (:52), `LimitOffsetPagination` (:126), `CursorPagination` (:190).
- JWT support is **behind a feature flag**: `djangors-rest = { version = "=0.7.0", features = ["jwt"] }`. Without it, `jsonwebtoken` is not compiled in.

### Originally established against 0.6.3 (confirm before use)

- `djangors_core::Router`: `.get()/.post()/.put()/.delete()` are 2-arg sugar; `.route(path, Method::X, handler)` is the 3-arg general form (needed for `PATCH`). `.mount(prefix, sub_router)` composes routers and inherits parent state for types the sub-router didn't set.
- `djangors_core::Request`: `.path() -> &str`, `.method() -> &hyper::Method`, `.header(name) -> Option<&HeaderValue>`, `.raw_query() -> Option<&str>`, `.require_state::<T>()` / `.state::<T>()`, `.body_bytes().await`.
- `djangors_core::DjangorsError`: construct with `DjangorsError::api(status, code, message)` and `.with_details(json)`. `.code()`/`.message()`/`.details()` are public. There is no `MethodNotAllowed` variant — use `DjangorsError::api(METHOD_NOT_ALLOWED, ...)`.
- `djangors_orm::OrmError` real variants: `Query(sqlx::Error)`, `NotFound{model}`, `MultipleObjectsReturned{model}`, `InvalidQuery(String)`, `FieldNotFound{field,model}`, `UnsupportedOnDialect(String)`, `SelectForUpdateOutsideTransaction`.
- `QuerySet<T>`: `.filter(q!(...))` (chainable, returns `Result<Self, OrmError>`), `.order_by(field)`, `.exclude(q!(...))`, `.select_for_update()` (transaction-only), `.all/.first/.get/.exists/.count(db)`, `QuerySet::<T>::insert_raw(db, values)`, `QuerySet::<T>::delete_by_pk(db, pk)`, `.update(db, set!(...))`.
- `#[derive(Model)]` supports `Uuid`, `Decimal` (with `max_digits`/`decimal_places`), `NaiveDate`, `NaiveTime`, `Duration` (persisted as text), `choices`, `auto_now`, `auto_now_add`. It rejects `i16` and `Option<ForeignKey<T>>` — use `i32`/`i64` and plain `Option<i64>` instead.
- Transactions: `Database::transaction(|conn| async { ... }).await`. Combine with `.select_for_update()` for race-safe read-then-write.
- `djangors_rest::Serializer<M>` trait: implement by hand when the wire shape needs field renaming (`public_id`→`id`) or FK-id-to-UUID expansion. The established pattern is: a plain `XRepresentation` struct + free `serialize_x(&XRepresentation) -> Value` function in `serializers.rs`, populated by an async `represent_x(db, &X)` resolver in `views.rs`.
- `djangors_rest` pagination: `PageNumberPagination` (default), `LimitOffsetPagination`, `CursorPagination`.
- PATCH bodies must be genuinely partial: contracts use `#[derive(Default, Deserialize)]` **plus** `#[serde(default)]` at the container level.
- `djangors_rest::current_user(&req).await -> Option<User>` is the one utility that covers session, token, and JWT auth.
- `djangors_contrib_tenancy::tenant_scope(req, qs, "tenant")` is the one-line helper for `Scoped::scope` when the model has a `tenant` FK.

## Permission model for Bloom Cloud

Bloom Cloud has organizations and projects. The permission model is role-based at the organization level, with project-level overrides.

Roles (organization-level):

- `Owner` — full control, can delete org, manage billing, manage members
- `Admin` — manage projects/apps/members, cannot delete org or change billing
- `Developer` — create builds, view releases, create deployments to non-production
- `Release Manager` — approve production deployments, manage signing/secrets
- `Viewer` — read-only

Every organization-scoped endpoint must check `OrganizationPermission`. Project-scoped endpoints must additionally check that the user has at least the project-level required role.

## Verification bar for "done"

An app/fix is not done when it compiles. It is done when:

1. `cargo fmt --check`, `cargo check --all-targets`, `cargo clippy --all-targets -- -D warnings`, and `cargo test` are clean.
2. Every route, status code, permission boundary, field, and ordering has been checked against the specification.
3. Every model has a reversible migration under `migrations/<app>/NNNN_<app>.sql` with explicit `-- up` and `-- down` sections.
4. Every write path that should emit an event does emit the event listed in `events.md`.
5. Anything genuinely out of reach in one pass is named explicitly, with the specific spec behavior it's standing in for.

## Do not

- Do not invent a Djangors API. Read the pinned `0.7.0` source before calling anything you're not already certain exists.
- Do not hand-roll a mechanism (pagination, caching, locking, validation errors, rate limiting, background tasks, typed settings, admin tenant scoping) before checking whether Djangors already has it.
- Do not deviate from the `APP_PATTERN.md` file layout for a single app "to keep it simple."
- Do not treat "it compiles and its own tests pass" as proof it matches the spec.
- Do not silently drop a piece of spec behavior because it was inconvenient to implement. Say so, plainly, with the reason.
## Background tasks and typed settings (0.7.0)

Djangors 0.7.0 ships a real background task system. Use it for anything that should not block a request: sending emails, updating platform API state, processing webhooks, expiring old data.

- `#[task]` from `djangors_tasks` registers a task at compile time via the `inventory` crate.
- `djangors_tasks::enqueue(db, "task_name", &payload).await` queues an immediate task.
- `djangors_tasks::enqueue_scheduled(db, "task_name", &payload, scheduled_at).await` queues a future task.
- `djangors_tasks::Worker::new(db).run().await` runs the worker loop.
- `djangors_tasks::register_recurring(db, "task_name", &payload, "0 0 * * *").await` registers a cron task; `tick_recurring_tasks` enqueues due instances.

For Bloom Cloud: use `djangors_tasks` for side effects (email, webhook async processing, audit cleanup, platform polling), **not** for the build/deploy worker queue itself. The build/deploy queue is a custom Redis-based job queue because it needs platform-specific worker containers, job tokens, and artifact lifecycle; but task machinery is the right default for all other background work.

Typed settings via `#[derive(djangors_macros::Settings)]` should be used for all app-specific configuration instead of manual `std::env::var` parsing. Example:

```rust
#[derive(djangors_macros::Settings, Debug)]
#[djangors(prefix = "BLOOM")]
struct BloomSettings {
    api_url: String,
    #[djangors(default = 30)]
    worker_claim_timeout_secs: u64,
    sentry_dsn: Option<String>,
}
```

