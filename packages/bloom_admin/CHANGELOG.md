# Changelog

## 0.2.1 - 2026-08-25

### Fixed
* fix: bump bloom_server dependency constraint from ^0.1.0 to ^0.2.0 — the stale constraint was incompatible with any sibling package (bloom_cache, bloom_i18n) requiring bloom_server ^0.2.0, breaking pub get in any app combining them.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

### Fixed
- `DefaultBloomModelAdmin.createFromForm` failed to compile because
  `QuerySet.insertRaw` returns `Future<dynamic>`; the primary key is now narrowed
  to `int?` explicitly.

## 0.1.0

- Initial release of `bloom_admin`: automatic, server-rendered HTML administration interface for Bloom applications.
- Mirroring `djangors-admin` architecture with `BloomAdminSite`, `BloomModelAdmin`, and `DefaultBloomModelAdmin`.
- Auto-generated changelist with pagination (`limit`/`offset`), multi-column ordering, search, and boolean filters.
- Auto-generated add/change forms with field-type mapping from `bloom_db` `FieldMeta`.
- Built-in CSRF token generation and server-side verification on all state-changing endpoints.
- Single and bulk object deletion with referential integrity protection awareness (`OnDelete.protect`).
- Safe-by-default server-side HTML rendering engine with strict auto-escaping.
