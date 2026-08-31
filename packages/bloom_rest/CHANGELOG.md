# Changelog

## 0.2.2 - 2026-08-31

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
