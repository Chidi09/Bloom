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

## 0.1.0

- Initial release of `bloom_validate`.
- Declarative `BloomRequestSchema` base class mirroring the `BloomEnvironmentSchema` error-collection pattern for HTTP JSON request bodies and DTOs.
- `BloomValidationException` with `.toResponse()` helper generating structured HTTP 400 Bad Request responses (`{"error": "...", "errors": [...]}`).
- Field validation rules:
  - Primitive fields: `requireString`, `optionalString`, `requireInt`, `optionalInt`, `requireBool`, `optionalBool`, `requireDouble`, `optionalDouble`, `requireUri`, `optionalUri`.
  - HTTP & DTO rules: `requireEmail`, `optionalEmail`, `requireStringLength`, `optionalStringLength`, `requireIntRange`, `optionalIntRange`, `requireEnum`, `optionalEnum`, `requireNested`, `optionalNested`, `requireList`, `optionalList`, `requirePrimitiveList`, `optionalPrimitiveList`.
