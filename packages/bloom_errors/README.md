# Bloom Errors (`bloom_errors`)

A strongly-typed HTTP error hierarchy, sibling package error-mapping registry, and dev/prod error-rendering middleware for `BloomApiRouter`.

Modeled after the `djangors` Rust ecosystem's `DjangorsError` pattern, `bloom_errors` provides a unified error-handling mechanism where typed domain exceptions convert cleanly into HTTP responses with status codes, machine-readable error codes, and environment-aware response masking.

---

## Features

- **Typed HTTP Exception Hierarchy**: Ready-to-throw subclasses (`BloomNotFoundException`, `BloomUnauthorizedException`, `BloomValidationFailedException`, etc.) carrying HTTP status codes, machine-readable error codes, and structured details.
- **Unified Error-Handling Middleware**: `BloomErrorMiddleware` acts as the outermost middleware for `BloomApiRouter`, intercepting exceptions from all downstream middlewares and route handlers.
- **Extensible Error Mapper (`BloomErrorMapper`)**: Maps domain and sibling package exceptions (`bloom_db`, `bloom_auth_server`, `bloom_storage`, `bloom_validate`, `bloom_migrate`) into appropriate `BloomApiException` instances without dependency cycles.
- **Dev-vs-Prod Information Masking**: Mask raw exception messages and stack traces in production (`APP_ENV=production`) while providing complete debugging context in development environments (`APP_ENV=local`).
- **Structured Error JSON Body**: Standardized `{ "error": { "code": "...", "message": "...", "details": { ... } } }` payload structure.

---

## Installation

Add `bloom_errors` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_errors:
    path: ../bloom_errors # or appropriate package path
  bloom_framework:
    path: ../bloom_framework
```

---

## Quick Start

### 1. Register Outermost Middleware

Register `BloomErrorMiddleware` **first** on `BloomApiRouter` so that it wraps the entire middleware pipeline and route handlers:

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';

void main() async {
  final router = BloomApiRouter();

  // Register BloomErrorMiddleware as the FIRST global middleware
  router.use(const BloomErrorMiddleware());

  // Additional middlewares and routes
  router.get('/api/users/:id', (req) async {
    final id = req.params['id'];
    if (id != '42') {
      throw BloomNotFoundException('User with ID $id was not found', {'user_id': id});
    }

    return BloomResponse.json({'id': id, 'name': 'Jane Doe'});
  });

  await router.serve(port: 8080);
}
```

---

## Usage Examples

### Example 1: Throwing `BloomNotFoundException` from a Route Handler

When a handler throws a `BloomApiException`, `BloomErrorMiddleware` intercepts it and formats a structured JSON response:

```dart
router.get('/api/products/:id', (req) async {
  final productId = req.params['id'];
  
  // Throwing a strongly-typed HTTP exception
  throw BloomNotFoundException('Product $productId does not exist', {
    'product_id': productId,
  });
});
```

#### HTTP Response (Status: `404 Not Found`)

```json
{
  "error": {
    "code": "not_found",
    "message": "Product 101 does not exist",
    "details": {
      "product_id": "101"
    }
  }
}
```

---

### Example 2: Registering a Custom Error Mapping

Application-level or custom service exceptions can be mapped into `BloomApiException` variants using `BloomErrorMapper.register<E>`:

```dart
class AccountSuspendedException implements Exception {
  final String accountId;
  final String reason;

  AccountSuspendedException(this.accountId, this.reason);
}

// In your application startup / bootstrap:
BloomErrorMapper.register<AccountSuspendedException>((e) {
  return BloomForbiddenException(
    'Account suspended: ${e.reason}',
    {'account_id': e.accountId, 'reason': e.reason},
  );
});

// In a route handler:
router.post('/api/transfers', (req) async {
  throw AccountSuspendedException('acc_99', 'Terms of service violation');
});
```

#### HTTP Response (Status: `403 Forbidden`)

```json
{
  "error": {
    "code": "forbidden",
    "message": "Account suspended: Terms of service violation",
    "details": {
      "account_id": "acc_99",
      "reason": "Terms of service violation"
    }
  }
}
```

---

### Example 3: Dev vs. Prod Mode for Unmapped Exceptions

When an unexpected exception (e.g. `FormatException`, `StateError`, or custom unmapped runtime errors) is thrown, `BloomErrorMiddleware` consults the environment variable `APP_ENV` via `BloomEnv.get('APP_ENV', defaultValue: 'local')`.

#### In Development Mode (`APP_ENV=local` or `APP_ENV=development`)

Internal errors reveal the full exception string and stack trace in `details` to facilitate rapid debugging:

```json
{
  "error": {
    "code": "internal_server_error",
    "message": "DatabaseConnectionTimeout: Failed to connect to pool at db.internal:5432",
    "details": {
      "type": "DatabaseConnectionTimeout",
      "stack_trace": "#0 DatabasePool.connect (package:app/db.dart:42)\n#1 main.<anonymous closure> (package:app/main.dart:18)..."
    }
  }
}
```

#### In Production Mode (`APP_ENV=production`)

Raw internal exception details and stack traces are completely masked:

```json
{
  "error": {
    "code": "internal_server_error",
    "message": "Internal Server Error"
  }
}
```

> **Note**: Intentionally thrown or mapped `BloomApiException` instances (such as `BloomNotFoundException` or `BloomValidationFailedException`) always expose their intended `message`, `code`, and `details` regardless of environment.

---

## Sibling Package Exception Mapping (Zero-Coupling Architecture)

`bloom_errors` path-depends **only** on `bloom_framework`. It does **not** hard-depend on sibling packages (`bloom_db`, `bloom_auth_server`, `bloom_storage`, `bloom_validate`, `bloom_migrate`).

To avoid circular dependencies and package bloat while still providing out-of-the-box mappings for all Bloom packages, `BloomErrorMapper` recognizes sibling exception types via **runtime type name matching** and dynamic property inspection:

| Sibling Package | Source Exception Type | Target `BloomApiException` | HTTP Status | Error Code (`code`) |
|---|---|---|---|---|
| `bloom_db` | `BloomOrmNotFoundError` | `BloomNotFoundException` | `404` | `not_found` |
| `bloom_db` | `BloomOrmMultipleObjectsReturnedError` | `BloomConflictException` | `409` | `conflict` |
| `bloom_db` | `BloomOrmInvalidQueryError` | `BloomBadRequestException` | `400` | `bad_request` |
| `bloom_db` | `BloomOrmFieldNotFoundError` | `BloomBadRequestException` | `400` | `bad_request` |
| `bloom_validate` | `BloomValidationException` | `BloomValidationFailedException` | `422` | `validation_failed` |
| `bloom_storage` | `BloomFileNotFoundException` | `BloomNotFoundException` | `404` | `not_found` |
| `bloom_storage` | `BloomStoragePathTraversalException` | `BloomForbiddenException` | `403` | `forbidden` |
| `bloom_storage` | `BloomStorageAuthException` | `BloomUnauthorizedException` | `401` | `unauthorized` |
| `bloom_storage` | `BloomStorageServerException` | `BloomInternalException` | `500` | `internal_server_error` |
| `bloom_auth_server` | `SessionTokenException` | `BloomUnauthorizedException` | `401` | `unauthorized` |
| `bloom_auth_server` | `PasswordResetException` | `BloomBadRequestException` | `400` | `bad_request` |
| `bloom_auth_server` | `RateLimitException` | `BloomTooManyRequestsException` | `429` | `too_many_requests` |
| `bloom_auth_server` | `AccountLockedException` | `BloomForbiddenException` | `403` | `forbidden` |
| `bloom_migrate` | `MigrationFileNotFoundException` | `BloomNotFoundException` | `404` | `not_found` |

---

## Standard Exception Classes & Error Code Contract

All built-in exception classes define stable, machine-readable `errorCode` strings:

| Class Name | HTTP Status | Default `errorCode` | Description |
|---|---|---|---|
| [`BloomBadRequestException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `400` | `"bad_request"` | Malformed syntax or invalid request parameters |
| [`BloomUnauthorizedException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `401` | `"unauthorized"` | Authentication required or invalid/expired session token |
| [`BloomForbiddenException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `403` | `"forbidden"` | Authenticated caller lacks permissions or resource is locked |
| [`BloomNotFoundException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `404` | `"not_found"` | Requested route, record, or file does not exist |
| [`BloomConflictException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `409` | `"conflict"` | Request conflicts with current state of the server/database |
| [`BloomValidationFailedException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `422` | `"validation_failed"` | Schema or payload validation failed (carries field errors) |
| [`BloomTooManyRequestsException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `429` | `"too_many_requests"` | Rate limit exceeded (supports `retryAfter` duration) |
| [`BloomInternalException`](file:///root/dev/Bloom/packages/bloom_errors/lib/src/http_exception.dart) | `500` | `"internal_server_error"` | Unexpected server or infrastructure failure |
