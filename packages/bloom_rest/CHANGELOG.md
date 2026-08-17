# Changelog

## 0.1.0

- Initial release of `bloom_rest` — DRF-style (Django REST Framework) REST layer on top of `BloomApiRouter` + `bloom_db`.
- `BloomSerializer`, `BloomModelSerializer`, `BloomNestedSerializer`, and `BloomFieldSet` for field-level read/write exposure control and validation.
- `BloomPagination` interface with `PageNumberPagination`, `LimitOffsetPagination`, and keyset `CursorPagination` (opaque base64 cursor encoding).
- Composable `BloomPermission` hierarchy (`AllowAny`, `IsAuthenticated`, `IsStaff`, `IsSuperuser`, `IsReadOnly`) with `.and()`, `.or()`, `.negate()`.
- `BloomThrottle` rate limiting with DRF rate strings (e.g. `"100/hour"`, `"10/minute"`) backed by `bloom_cache`'s `BloomCache`.
- Composable `BloomFilterBackend` stack: `BloomFieldFilter`, `BloomSearchFilter`, `BloomOrderingFilter`.
- `BloomViewSet` for complete CRUD route mounting onto `BloomApiRouter` in a single call with secure-by-default authentication posture.
