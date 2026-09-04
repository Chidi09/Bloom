# Changelog

## 0.2.2 - 2026-09-04

### Added
* **New common HTTP exception types (#30)**: `BloomMethodNotAllowedException` (405 `method_not_allowed`, with optional `allowed` methods in `details`), `BloomServiceUnavailableException` (503 `service_unavailable`), plus `BloomRequestTimeoutException` (408) and `BloomUnsupportedMediaTypeException` (415) following the existing patterns.
* **Request correlation in `onError` (#30)**: `BloomErrorMiddleware` gains `onErrorWithContext(error, stackTrace, request)`, giving observability callbacks access to the originating `BloomRequest` (method/URI) for correlation. The existing two-parameter `onError` callback is unchanged and remains source-compatible; set either or both.

### Fixed
* **Throwing `onError` no longer escapes (#30)**: exceptions thrown by the `BloomErrorMiddleware.onError` logging callback are caught (and logged to the console) instead of propagating out of the error path and breaking the error response.
* **429 `Retry-After` header merge (#30)**: `BloomTooManyRequestsException.toResponse` now spreads caller-supplied headers first so the computed `Retry-After` value wins instead of being clobbered by a caller-provided (possibly stale) header.

### Documentation
* Warned against putting secrets/PII in `BloomApiException.details` (echoed verbatim to clients and included in `toString()` output that gets logged).

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
