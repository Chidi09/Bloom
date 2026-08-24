/// Strongly-typed HTTP error hierarchy, sibling package exception mapping registry, and
/// HTTP error-rendering middleware for Bloom applications.
///
/// The `bloom_errors` package provides a unified error handling architecture for Bloom server
/// applications. It consists of three primary subsystems:
///
/// 1. **HTTP Exception Hierarchy**: Strongly-typed exceptions ([BloomApiException] and its subclasses
///    such as [BloomNotFoundException], [BloomBadRequestException], [BloomValidationFailedException],
///    [BloomUnauthorizedException], [BloomForbiddenException], [BloomConflictException],
///    [BloomTooManyRequestsException], and [BloomInternalException]) carrying HTTP status codes,
///    machine-readable error codes, and structured details.
/// 2. **Exception Mapping Registry** ([BloomErrorMapper]): Translates sibling package exceptions
///    (e.g., `bloom_db`, `bloom_auth_server`, `bloom_storage`, `bloom_validate`, `bloom_migrate`)
///    and standard Dart core exceptions into appropriate [BloomApiException] instances without
///    requiring tight compile-time coupling. Custom domain exceptions can also be registered via
///    [BloomErrorMapper.register] or [BloomErrorMapper.registerByName].
/// 3. **Error Middleware** ([BloomErrorMiddleware]): Outermost middleware for `BloomApiRouter`
///    that intercepts all uncaught errors, maps them to [BloomApiException] instances, and renders
///    consistent JSON error responses with environment-aware masking (hiding internal details in
///    production).
///
/// ### End-to-End Example
///
/// ```dart
/// import 'package:bloom_server/bloom_server.dart';
/// import 'package:bloom_errors/bloom_errors.dart';
///
/// void main() async {
///   final router = BloomApiRouter();
///
///   // Register custom domain exception mappers
///   BloomErrorMapper.register<UserNotFoundException>(
///     (e) => BloomNotFoundException('User ${e.userId} was not found', {'user_id': e.userId}),
///   );
///
///   // Register BloomErrorMiddleware as the FIRST global middleware
///   router.use(const BloomErrorMiddleware());
///
///   // Downstream route handler throwing strongly-typed HTTP exceptions
///   router.get('/api/users/:id', (req) async {
///     final id = req.params['id'];
///     if (id != '42') {
///       throw BloomNotFoundException('User with ID $id was not found', {'user_id': id});
///     }
///     return BloomResponse.json({'id': id, 'name': 'Jane Doe'});
///   });
/// }
///
/// class UserNotFoundException implements Exception {
///   final String userId;
///   UserNotFoundException(this.userId);
/// }
/// ```
library;

export 'src/error_mapper.dart';
export 'src/error_middleware.dart';
export 'src/http_exception.dart';
