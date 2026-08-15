# Backend Audit — verification gaps

Date: 2026-08-15. Original commit: `76e3117`.

## Status

| Finding | State |
|---|---|
| S1 fake build artifact | Fixed — `3cf1971` |
| S2 fake deploy bundles | Fixed — `3cf1971` |
| S3 hardcoded signing key | Fixed — `c99e5d2` |
| S4 no rate limiting | Fixed — `c99e5d2` |
| S5 credential validation is simulated | **Open** — needs live API calls, pairs with the integration pass |
| C1 unbounded list endpoints | Partly fixed — `b4bcc69` covered builds/events/artifacts/deployments/releases; remaining apps in flight |
| C2 N+1 lookups | Partly fixed — same commit and scope as C1 |
| C3 no transactions | Partly fixed — `e3d412d` made install recording atomic; other multi-step writes still unwrapped |
| F1 framework surface unused | Largely fixed — pagination, throttling, SSE, and djangors-tasks all adopted |
| F2 fabricated constants | Fixed |

Two findings surfaced during the fixes and are also closed:

- **`slugify` was duplicated five times and had drifted**, with the marketplace copy able to
  panic on a user-supplied name (`8e6a867`).
- **Install counters were read-modify-written**, so concurrent installs silently lost
  increments (`e3d412d`).

One constraint worth knowing before more transactional work: the `Model` derive generates
`save`/`update` taking `&Database`, while `transaction_conn` hands the closure a `&mut Conn`.
Model helpers therefore cannot be used inside a transaction; the `QuerySet` write paths
(`bulk_create`, `update`, `insert_raw`) are generic over `DbExecutor` and are the supported
route. This is a framework constraint, not a preference.

Every finding below is grepped from the tree, not inferred. Line references are real.

The theme is one failure mode with two faces: **code was written to look
correct rather than to be correct**, and **the framework was never read**, so
capabilities that ship with Djangors 0.7.0 were skipped or reimplemented.

---

## S1 — The build worker uploads a fake artifact

`src/workers/build.rs:1092`, stage 9 of 9, the main path. Not a test double.

```rust
let dummy_artifact_bytes = Bytes::from(format!(
    "Bloom build output bundle for {build_id} (platform: {platform})"
));
let dummy_size = dummy_artifact_bytes.len() as i64;
let dummy_checksum =
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".to_string();
```

Stages 1–8 run real Flutter commands. Stage 9 discards whatever they produced
and uploads a ~60-byte text string under the name `app-release.aab` or
`Runner.ipa`, then registers it as the build's artifact and reports success.

The checksum is fabricated on top of that: `e3b0c442…b855` is the SHA-256 of the
**empty string**, and the bytes stored are not empty. So the recorded checksum
does not match the stored object even on its own terms.

Everything downstream consumes this: deployments, releases, TestFlight upload,
Shorebird patches. The artifact integrity check in `infrastructure.md` §9
("workers must verify upload success via ETag/head request") is not performed.

## S2 — Deploy worker ships fake bundles, including to Google Play

Three sites, all production paths.

`src/workers/deploy.rs:781` — uploads a fabricated AAB to the **real** Google
Play API:

```rust
let dummy_bundle_bytes =
    Bytes::from_static(b"PK\x03\x04\x14\x00\x00\x00\x00\x00DummyAABBundlePayload");
client.upload_bundle(package_name, edit_id, dummy_bundle_bytes, None)
```

`src/workers/deploy.rs:569-583` — web hosting deploys a hardcoded HTML stub and
`"// Flutter Web bootstrap dummy bundle\n"` as `main.dart.js`, rather than the
built web bundle.

## S3 — Signing key falls back to a key published in this repo

`src/apps/emails/views.rs:57`:

```rust
fn get_signing_key() -> Vec<u8> {
    std::env::var("BLOOM_ENCRYPTION_KEY")
        .or_else(|_| std::env::var("ENCRYPTION_KEY"))
        .unwrap_or_else(|_| {
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".to_string()
        })
        .into_bytes()
}
```

If the env var is unset in production, unsubscribe tokens are signed with a key
anyone reading the source can copy, so anyone can forge them for any user.

A missing encryption key must be a hard boot error. `infrastructure.md` §7 already
says settings `load()` failures are hard boot errors; this bypasses that by
reading `std::env::var` directly.

## S4 — No rate limiting anywhere

`djangors_core::ratelimit` ships `rate_limited`, `ByIp`, `RateLimiter`. Uses in
our tree: **zero**. The only matches for "rate limit" are Stripe's client-side
429 handling in `src/infra/stripe.rs`.

So `/auth/login` has no brute-force protection, `/auth/register` no abuse
protection, and `/auth/device/token` — an endpoint whose entire purpose is to be
polled in a loop — has no throttle.

## S5 — Credential validation validates nothing

`src/apps/credentials/services.rs:259`, comment reads "Provider-specific offline
validation checks (simulated connection test)". It checks `key_id.len() < 2`.

A user connecting Apple or Google Play credentials is told they are valid when
nothing contacted Apple or Google. The failure surfaces later, during a deploy.

---

## C1 — Every list endpoint is unbounded

29 `list_*` views; **89** sites doing `Response::json(StatusCode::OK, &payload)`
over a full `Vec`. No `LIMIT` anywhere.

`GET /api/v1/events` returns an organization's entire event history in one
response — and the event log is append-only, written on every state change on
the platform.

Djangors ships all three strategies in `djangors-rest-0.7.0/src/pagination.rs`
(`PageNumberPagination`, `LimitOffsetPagination`, `CursorPagination`, the last
being keyset and issuing no `COUNT`). Uses in our tree: zero.

## C2 — N+1 on top of C1

`prefetch_related` / `select_related` uses: **zero**.

`src/apps/builds/services.rs:447` issues **four queries per row**:

```rust
for build in builds {
    let stages = repositories::buildstages_for_build(db, build.id).await?;
    let app_public_id = repositories::app_public_id_by_id(db, build.app_id.id).await?
    let environment_public_id = repositories::environment_public_id_by_id(db, ...).await?
    let org = repositories::organization_summary_by_id(db, organization_id).await?
```

The last one is loop-invariant — the same `organization_id` every iteration —
so it refetches an identical row once per build. 1,000 builds is ~4,000 queries
returning all 1,000 rows.

## C3 — No transactions

`Database::transaction_conn` uses: **zero**. All 34 "transaction" matches in
`src/apps/` are doc comments or unrelated words ("transactional email").

`infrastructure.md` §7 explicitly instructs using it. Multi-step writes are
therefore non-atomic — a marketplace purchase writes the purchase, the
entitlement, and the payout as three independent statements, and a failure
between them leaves a customer charged with no entitlement.

---

## F1 — Framework surface almost entirely unused

Available vs. imported:

| Crate | Ships | We import |
|---|---|---|
| `djangors-rest` | auth, filters, openapi, pagination, permissions, serializers, throttling, validation, viewsets | `current_user`, `decode_jwt`, `encode_jwt` |
| `djangors-core` | sse, ratelimit, pagination, signals, middleware, groups, logging | `error`, `extract`, `request`, `router`, `logging`, `middleware` |
| `djangors-orm` | query_cache, aggregate, signals, prefetch | `expr` |

Consequences already priced in above: pagination (C1), rate limiting (S4).
Two more:

- **`djangors_core::sse` + `StreamingHandler` exist.** The live-events endpoint
  the dashboard needs is adoption, not new work. ~94 lines in `sse.rs` provide
  `StreamingResponse::sse`.
- **`djangors_rest::openapi` exists** but generates CRUD paths per `Model`. It
  cannot describe our 155 hand-registered routes, and its model-derived schemas
  contradict our wire contract (models expose `id: i64` + `public_id`; responses
  expose `id` as the UUID). Correct path is `schemars` on the `contracts::*`
  structs, which already are the wire format.

## F2 — Fabricated constants in shipped code

Pattern already corrected three times (fabricated JWT keypairs in the TestFlight
and Google Play tests; invented altool error code `1519`). The sweep for long
hex literals now returns only S1's fake checksum plus legitimate values (RFC 4231
HMAC vectors in `tests/apps/git_connections/services.rs`, verified published).

---

## What is actually sound

Not everything is suspect, and the audit should say so:

- **Indexes.** 92 `CREATE INDEX` in migrations, `db_index` used on models. Done properly.
- **Multi-tenancy.** `Scoped` + `OrganizationPermission` with a real 5-level role
  hierarchy; org scoping is applied at the queryset level.
- **Money.** Integer minor units throughout; no float anywhere near currency.
- **Wire contract.** Internal `i64` never crosses the boundary; `public_id` UUIDs
  consistently, in every serializer checked.
- **Webhook signature verification.** Real HMAC over raw bytes, timing-safe,
  verified against published RFC vectors.
- **Encryption.** AES-256-GCM with versioned `v1:` prefix and random nonce.

---

## Suggested order

Sequenced by blast radius, not by effort.

1. **S1, S2** — fake artifacts. The core product claim is false while these stand.
2. **S3, S4** — key fallback and rate limiting. Both are small and both are live exposure.
3. **C3** — transactions around purchase, subscribe, build creation.
4. **C1, C2** — pagination and N+1 together; they share the same call sites.
5. **S5** — real credential validation (needs live API calls, so it pairs with the integration pass).
6. **F1** — SSE endpoint, then schemars/OpenAPI. Both unblock the console.

Items 1–4 should land before the frontend consumes these endpoints; item 6
determines the console's data layer shape, so it should land before tables are
built.

---

## V1 — ViewSet migration is blocked in djangors-rest 0.7.0

Investigated 2026-08-15 while attempting to mount the 315 in-app routes through
`ScopedViewSet` instead of hand-written handlers. The migration cannot proceed
as-is. Three facts, each verified in the crate source:

1. **Detail paths are hardcoded to the integer primary key.** Every route helper
   builds `format!("{clean_base}/{{pk:i64}}")` (`viewsets.rs:1095`, and the same
   line in each sibling helper). There is no `lookup_field` option in 0.7.0.
   Our wire contract is the opposite: internal `i64` PKs never cross the API
   boundary, and all 315 of our detail routes are keyed by public UUID
   (`/releases/{id}`). We have zero `pk:i64` routes.

2. **The scoped helpers accept no serializer and no permission.**
   `scoped_viewset_routes_with_config` takes only `ViewSetConfig` and hardcodes
   `IsAuthenticated` (`viewsets.rs:1101`). The helper that does accept a custom
   serializer and an explicit permission — `viewset_routes_with_options<M, P>`
   (`viewsets.rs:1209`) — is built on the unscoped `ViewSet<M>`, so it applies no
   tenant row filter. Using it in a multi-tenant system would expose rows across
   organizations. The combination we need (scoped + serializer + role permission)
   does not exist.

3. **The default serializer emits raw foreign-key integers.** `serializers.rs:11`:
   "Relation fields serialize as their raw related id integer/null." Our
   responses embed the *related object's* `public_id` (`app_public_id`,
   `organization_public_id`, …). Mounting the default serializer would both break
   the contract asserted by 557 tests and leak internal PKs.

Point 1 alone blocks every detail route; point 2 blocks every write route on a
role-guarded resource; point 3 blocks every list route.

**This is not an argument against ViewSets.** The 45 `Scoped` impls are already
written and correct. Unblocking needs one of:

- a `lookup_field` (or `lookup: Uuid`) option on the viewset helpers, plus a
  `scoped_viewset_routes_with_options` that takes `ViewSetOptions` and a
  `Permission` — a framework change; or
- accepting `i64` PKs in URLs — a breaking wire-contract change we should not
  make silently; or
- leaving these routes hand-written, which is the current state and is correct,
  just verbose.

Until one is chosen, hand-written handlers are the right call and the duplication
removed in `088d253` and `263738b` is the realistic win.
