# The standard — how to add a domain app

`APP_PATTERN.md` defines the required *shape*. This document is the *procedure*, grounded in the
two apps that already exist and pass every gate. Read both before starting an app.

Reference implementations in this repo:

| App | What it demonstrates |
|-----|----------------------|
| `src/apps/accounts/` | The golden app: layout, error mapping, service/repository split, JWT issuance |
| `src/apps/organizations/` | An **organization-scoped** app: `Scoped`, role permissions, resolution middleware |
| `src/apps/common/scoping.rs` | The shared `organization_scope` helper every scoped app must reuse |
| `src/infra/` | Cross-cutting infrastructure (crypto, storage, queue) — not a domain app |

---

## 1. Where code lives

The module tree lives in the **library crate** (`src/lib.rs`). `src/main.rs` is a thin binary that
does `use bloom_cloud_backend::{...}`.

> **Do not add `mod <app>;` to `src/main.rs`.** Doing so compiles a second, private copy of the
> whole module tree into the binary, where every `pub` item is unreachable — which surfaces as a
> flood of spurious `never constructed` / `never used` clippy errors, and doubles compile time.
> This actually happened; the fix was to make `main.rs` consume the lib crate.

---

## 2. The layout

Exactly as `APP_PATTERN.md` specifies:

```
src/apps/<app>/{mod.rs,models.rs,contracts.rs,serializers.rs,repositories.rs,
                services.rs,permissions.rs,views.rs,urls.rs,errors.rs}
migrations/<app>/NNNN_<app>.sql          reversible: explicit `-- up` and `-- down`
tests/apps/<app>/{models.rs,services.rs,permissions.rs,api.rs}
```

`errors.rs` is not listed in `APP_PATTERN.md` but is part of the house pattern in both the reference
backend and `accounts`. Include it.

Flow: `urls -> views -> permissions/contracts/services -> repositories -> ORM`. No SQL or business
rules in `views.rs`. No HTTP responses or role decisions in `repositories.rs`. No `#[cfg(test)]`,
`#[test]`, or `#[tokio::test]` anywhere under `src/`.

---

## 3. Wiring a new app in (3 shared files)

These are the **only** places an app registers itself. When apps are built in parallel, dispatches
must NOT edit them — whoever writes last silently clobbers the others. Wire them centrally after the
app lands.

1. **`src/lib.rs`** — `pub mod apps;` already exists; add the app inside `src/apps/mod.rs`:
   ```rust
   pub mod <app>;
   ```
2. **`src/apps/mod.rs`** — mount the router:
   ```rust
   Router::new()
       .mount("", accounts::urls())
       .mount("", <app>::urls())
   ```
3. **`src/migrations.rs`** — append to `MIGRATIONS`. **Array order is apply order**, so a table must
   be registered after anything its foreign keys reference:
   ```rust
   MigrationRef { app: "<app>", path: "migrations/<app>" },
   ```

---

## 4. Wire contract (every app, no exceptions)

* Internal `i64` primary keys **never** cross the API boundary.
* Every model carries `public_id: String` (UUID v4), exposed in JSON as `"id"` — never `"public_id"`.
* Foreign keys cross the wire as the related row's UUID string, in requests and responses.
* Money is integer minor units (`amount_cents: i64`). Never float, never `Decimal`.
* Status fields are uppercase `Snake_Case` strings over the wire, exactly as the model choices define.
* Errors use `DjangorsError::api(status, code, message)`, optionally `.with_details(json)`.
* PATCH bodies are genuinely partial: `#[derive(Default, Deserialize)]` **plus** `#[serde(default)]`
  at the container level.
* Request contracts derive **`Deserialize` only**; response contracts derive `Serialize`. A request
  DTO is parsed from an inbound body and never emitted — do not add `Serialize` to one just to make
  a test compile. Test the inbound direction against literal JSON instead.

---

## 5. Organization scoping

Every organization-scoped model implements `Scoped` using the shared helper. Do not write a second
scoping helper.

```rust
impl Scoped for MyModel {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
```

`djangors_rest::Scoped` is `trait Scoped: Model + FromRow + Send + Sync + 'static`
(`djangors-rest/src/viewsets.rs:265`) — the `FromRow` bound is easy to miss.

Cross-organization isolation is this product's security boundary. Every app's
`tests/apps/<app>/permissions.rs` must prove that a user in organization A cannot read or write
organization B's rows.

---

## 6. Settings

All configuration is typed in `src/settings.rs` via `#[derive(Settings)]`. Nothing calls
`std::env::var` directly.

The derive is **flat**: each field maps to `{PREFIX}_{FIELD_UPPERCASED}`. It supports
`#[djangors(prefix = "...")]`, `#[djangors(default = ...)]`, and `Option<T>` (unset → `None`, never
an error). There is **no nested-struct support**, so each integration gets its own struct and prefix.

After adding or changing a field, update `.env.example` to match — it is the contract users see.

---

## 7. Verified API facts worth not rediscovering

Confirmed against the pinned source at `/root/dev/Rango/crates/` (tag `v0.7.0`). See
`AI-AGENT-PRINCIPLES.md` for the full list.

* Handler signature takes **two** arguments:
  `async fn h(req: Request, params: PathParams) -> Result<Response, DjangorsError>`.
* `QuerySet::count()` returns **`Result<i64, _>`**, not `u64` (`djangors-orm/src/queryset.rs:962`).
* `djangors_core` re-exports **`StatusCode` only** (`lib.rs:76`) — not `Method`, not `Request`.
  `hyper` is a direct dependency for tower `Service` impls; import `Method` from `hyper`.
* Parsing a string into an enum: implement **`std::str::FromStr`**, not an inherent `from_str`
  method. Clippy rejects the latter under `-D warnings`.
* `djangors_cache::Cache` is a get/set/delete KV trait (`djangors-cache/src/lib.rs:37`). It cannot
  express Redis Streams consumer groups, which is why the build/deploy queue in `src/infra/queue.rs`
  uses the `redis` crate directly. Use `djangors-tasks` for ordinary background side effects.

### Error rendering — the framework does this; do not hand-roll it

Djangors renders errors natively. There is no need for a bespoke error-response builder.

* `DjangorsError::render(&self, req, debug)` (`djangors-core/src/error.rs:219`) is the single entry
  point. Error responses **content-negotiate**: a project `ErrorRenderer` wins, then the JSON
  envelope when the caller sent `Accept: application/json` or the error is an `ApiError`, then the
  Django-style debug page in development or the production error page otherwise. This applies to
  every route, not just REST.
* `ErrorRenderer` is a trait — `fn render(&self, err: &DjangorsError, req: &Request) -> Response`
  (`error.rs:12`). Register one project-wide with **`Router::set_error_renderer(renderer)`**, which
  is **new in 0.7.0**.
* `code()`, `message()`, and `details()` are public, so a custom renderer can build its own envelope
  without re-matching on the variant. The JSON envelope omits `details` entirely when absent.
* `ValidationErrors` gives a `{field: [messages]}` map with `non_field_errors`.
* `ApiResultExt` (`.api_err(status, code)` / `.api_err_msg(...)`) converts foreign errors at the `?`
  site without a `map_err` closure.

> **Trap:** `with_state(Arc::new(MyRenderer))` *compiles* but stores the value under its concrete
> type, where the renderer lookup never finds it — your custom renderer is then **silently ignored**.
> Always use `Router::set_error_renderer`.

What each app still owns is the **domain → API mapping**: a typed error enum in `errors.rs` plus
`impl From<MyAppError> for DjangorsError` using `DjangorsError::api(status, code, message)`. That is
the intended pattern (see `accounts/errors.rs`), not hand-rolling. The reference backend predates
`set_error_renderer` because it is pinned `=0.6.3`; do not copy a workaround from it.

### The `cfg(feature = ...)` trap

`#[cfg(feature = "jwt")]` tests **this crate's** features, not a dependency's. `jwt` is a feature of
`djangors-rest`; this crate declares no such feature, so such a gate is **always false** and the
`#[cfg(not(...))]` branch is what compiles. This shipped once in `accounts` and silently replaced
real JWT signing with `format!("dev-token-{}", user.id)`, plus a refresh path that accepted any token
and returned user 1. Never gate behaviour on a dependency's feature name.

---

## 8. Definition of done

An app is done when all four gates are clean **and** it matches its spec:

```bash
cargo fmt --check
cargo check --all-targets
cargo clippy --all-targets -- -D warnings
cargo test
```

Compiling is not proof of correctness. Re-read `apps/<app>.md` beside the code and check every model
field, status code, permission boundary, event name, and ordering. Anything genuinely out of reach in
one pass must be named explicitly with the spec behaviour it stands in for — a truthful
`// TODO(spec):` beats a fabricated implementation every time.
