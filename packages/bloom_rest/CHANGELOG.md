# Changelog

## Unreleased

### Added
* **Object-level authorization hook (#5)**: `BloomRestPermission.hasObjectPermission(req, item)` (default: allow) is enforced after fetching the row in `retrieve`/`update`/`destroy`; denial returns 404 so denied ids are indistinguishable from missing ones. `update`/`destroy` now fetch before mutating so authz precedes writes. AND/OR/NOT combinators propagate object checks. Stock ViewSets document that request-level permission alone does not scope rows — override the hook (or scope `getDb`/filters) for owner/tenant data.
* **`onInternalError` sink on `BloomViewSetOptions` (#6)**: unexpected 5xx errors route to this callback (print fallback) for server-side diagnosis.

### Security
* **Generic 500 bodies (#6)**: `retrieve`/`create`/`update`/`destroy` no longer interpolate raw exceptions into responses; all 5xx bodies are `Internal Server Error`.
* **Shared anonymous bucket warning (#8)**: `ByUserOrIp` prints a loud one-time warning when all anonymous callers share the fallback bucket; README and docs show `peerAddressExtractor` wiring, and throttle-before-permission ordering rationale is recorded on the ViewSet guard.

### Fixed
* **Default max page size (#7)**: `BloomViewSetConfig.maxPageSize`, `PageNumberPagination.maxPageSize`, and `CursorPagination.maxPageSize` now default to `kRestPerPage` (100), so `?page_size=1000000` is clamped instead of becoming a full-table scan plus uncached count.
* **REST hardening bundle (#9)**: malformed/invalid cursor tokens now return 400 instead of silently returning page one; cursor pagination documents its forward-only `previous_cursor: null` behavior; `InMemoryAtomicThrottleStore` evicts least-recently-used keys at its configurable cap; boolean/date coercions reject fractional numbers and garbage dates; nested serializer relation-name mismatches throw `ArgumentError`.

## 0.2.2 - 2026-08-31

### Fixed

- **`bloom_rest` could not be resolved by any consumer.** The package depended on
  `bloom_cache ^0.2.0`, but `bloom_cache` 0.2.x depends on `bloom_server ^0.1.0`, which
  contradicts this package's own `bloom_server ^0.2.0` — so `pub get` failed with
  "version solving failed" on 0.2.0 and 0.2.1. The constraint is now `bloom_cache ^0.3.0`
  (0.3.0 being the first `bloom_cache` release on `bloom_server ^0.2.0`), which is what
  the monorepo's `dependency_overrides` already resolved to. Those overrides are why the
  contradiction never showed up in local builds or tests.

### Security & Hardening
- **Throttling Race Condition Elimination & Atomic Store Support**:
  - Introduced `BloomAtomicThrottleStore` and `InMemoryAtomicThrottleStore` for race-free sliding-window rate limiting.
  - Documented that non-atomic `BloomCache` fallback is subject to get-modify-set races under concurrent multi-process environments.
  - Hardened `ByUserOrIp` with immediate transport peer extraction (`PeerAddressExtractor`) and `TrustedProxyPredicate`. Forwarding headers (`X-Forwarded-For`, `X-Real-IP`) are never trusted unless verified against trusted proxies; falls back to a non-spoofable shared fallback key (`anon:shared_untrusted`).
- **Sensitive Field Filtering (Secure by Default)**:
  - `BloomModelSerializer` now excludes conventionally sensitive fields (`password`, `password_hash`, `token`, `access_token`, `refresh_token`, `secret`, `api_key`) from serialized response output and write input by default.
  - Added `includeSensitiveFields` configuration option (default `false`) on `BloomModelSerializer` to explicitly opt into sensitive field handling when needed.
- **Permission Responses**:
  - Updated ViewSet permission guards to return `401 Unauthorized` strictly when no verified caller identity exists, and `403 Forbidden` for authenticated callers denied by a permission policy.
- **Deterministic Keyset Cursor Pagination**:
  - Fixed `CursorPagination` to honor `CursorPagination.orderingField` when query parameters are omitted.
  - Applied deterministic query ordering with primary-key tie-breaker (`(orderField, pkField)`) and matching composite cursor predicates to eliminate pagination drift.

## 0.2.1 - 2026-08-25

### Fixed
* Bumped `bloom_server` dependency constraint from `^0.1.0` to `^0.2.0` — the stale constraint was incompatible with any sibling package (`bloom_cache`, `bloom_i18n`) requiring `bloom_server ^0.2.0`, breaking `pub get` in any app combining them.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_rest` — DRF-style (Django REST Framework) REST layer on top of `BloomApiRouter` + `bloom_db`.
- `BloomSerializer`, `BloomModelSerializer`, `BloomNestedSerializer`, and `BloomFieldSet` for field-level read/write exposure control and validation.
- `BloomPagination` interface with `PageNumberPagination`, `LimitOffsetPagination`, and keyset `CursorPagination` (opaque base64 cursor encoding).
- Composable `BloomPermission` hierarchy (`AllowAny`, `IsAuthenticated`, `IsStaff`, `IsSuperuser`, `IsReadOnly`) with `.and()`, `.or()`, `.negate()`.
- `BloomThrottle` rate limiting with DRF rate strings (e.g. `"100/hour"`, `"10/minute"`) backed by `bloom_cache`'s `BloomCache`.
- Composable `BloomFilterBackend` stack: `BloomFieldFilter`, `BloomSearchFilter`, `BloomOrderingFilter`.
- `BloomViewSet` for complete CRUD route mounting onto `BloomApiRouter` in a single call with secure-by-default authentication posture.
