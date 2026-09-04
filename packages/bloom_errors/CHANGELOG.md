# Changelog

## Unreleased

### Security
* **Mapped 500s use generic messages (#28)**: ORM, storage, migrate, and `mapToHttpException`-fallback mappings no longer embed raw `error.toString()` (driver/SQL/filesystem internals) into `BloomApiException`s, which render verbatim in every environment. Raw details remain available via `onError` and non-prod output.
* **Deny-by-default environment masking (#29)**: 500s are masked unless the environment is an explicit dev value (`local`, `dev`, `development`, `test`). `staging`/`prod`/`qa`/`preview`/unknown values no longer leak stack traces. Recognized values are documented on `BloomErrorMiddleware`.

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

- Initial release of `bloom_errors`.
- `BloomHttpException` base class and standard subclasses:
  - `BloomBadRequestException` (`bad_request`, 400)
  - `BloomUnauthorizedException` (`unauthorized`, 401)
  - `BloomForbiddenException` (`forbidden`, 403)
  - `BloomNotFoundException` (`not_found`, 404)
  - `BloomConflictException` (`conflict`, 409)
  - `BloomValidationFailedException` (`validation_failed`, 422)
  - `BloomTooManyRequestsException` (`too_many_requests`, 429)
  - `BloomInternalException` (`internal_server_error`, 500)
- `BloomErrorMapper` registry for mapping arbitrary domain and sibling package exceptions (from `bloom_db`, `bloom_auth_server`, `bloom_storage`, `bloom_validate`, `bloom_migrate`, etc.) to HTTP exceptions without introducing tight coupling or dependency cycles.
- `BloomErrorMiddleware` for global exception interception, dev-vs-prod masking via `APP_ENV`, and uniform JSON error payloads.
