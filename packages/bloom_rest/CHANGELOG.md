# Changelog

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
