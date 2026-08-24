// lib/src/http_exception.dart
import 'package:bloom_server/bloom_server.dart';

/// Base abstract class for all strongly-typed HTTP exceptions in the Bloom framework.
///
/// Subclasses carry an HTTP [statusCode], a human-readable [message], a machine-readable
/// [errorCode] (e.g. `"not_found"`, `"unauthorized"`), and optional structured [details].
///
/// Handled automatically by [BloomErrorMiddleware] to produce standardized JSON error responses.
///
/// Example:
/// ```dart
/// class BloomPaymentRequiredException extends BloomApiException {
///   const BloomPaymentRequiredException([String message = 'Payment Required'])
///       : super(
///           statusCode: 402,
///           message: message,
///           errorCode: 'payment_required',
///         );
/// }
/// ```
abstract class BloomApiException implements Exception {
  /// HTTP status code (e.g. 404, 401, 500).
  final int statusCode;

  /// Human-readable explanation of the error.
  final String message;

  /// Short machine-readable string identifier for the error category (e.g. `'not_found'`).
  final String? errorCode;

  /// Additional structured context, field validation errors, or debug info.
  final Map<String, dynamic>? details;

  /// Creates a new [BloomApiException].
  ///
  /// Requires an HTTP [statusCode] and a human-readable [message]. Optionally accepts
  /// a machine-readable [errorCode] and structured [details] map.
  const BloomApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.details,
  });

  /// Serializes the error into a structured JSON map containing `'code'`,
  /// `'message'`, and optionally `'details'`.
  ///
  /// Example:
  /// ```dart
  /// final exception = BloomNotFoundException('Item 123 not found');
  /// final jsonMap = exception.toJson();
  /// // {'code': 'not_found', 'message': 'Item 123 not found'}
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'code': errorCode ?? 'error',
      'message': message,
      if (details != null && details!.isNotEmpty) 'details': details,
    };
  }

  /// Converts this exception directly into a formatted JSON [BloomResponse].
  ///
  /// Sets the HTTP response status code to [statusCode] and wraps [toJson] inside
  /// a top-level `{'error': ...}` object. Additional HTTP [headers] can be supplied.
  ///
  /// Example:
  /// ```dart
  /// final response = BloomNotFoundException('User not found').toResponse();
  /// print(response.statusCode); // 404
  /// ```
  BloomResponse toResponse({Map<String, String>? headers}) {
    return BloomResponse.json(
      {
        'error': toJson(),
      },
      statusCode: statusCode,
      headers: headers,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('BloomApiException($statusCode, $errorCode): $message');
    if (details != null && details!.isNotEmpty) {
      buffer.write(' Details: $details');
    }
    return buffer.toString();
  }
}

/// 400 Bad Request exception.
///
/// Thrown when the client sends a malformed request, invalid query parameters,
/// or syntactically incorrect payload.
///
/// Example:
/// ```dart
/// if (queryParam == null) {
///   throw const BloomBadRequestException('Missing required parameter: query');
/// }
/// ```
class BloomBadRequestException extends BloomApiException {
  /// Creates a new [BloomBadRequestException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Bad Request'`) and
  /// additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomBadRequestException('Invalid sorting order', {'sort': 'invalid_col'});
  /// ```
  const BloomBadRequestException([
    String message = 'Bad Request',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 400,
          message: message,
          errorCode: 'bad_request',
          details: details,
        );
}

/// 401 Unauthorized exception.
///
/// Thrown when authentication is required and has either failed or has not yet
/// been provided (e.g. missing, expired, or invalid credentials/tokens).
///
/// Example:
/// ```dart
/// if (authHeader == null) {
///   throw const BloomUnauthorizedException('Authorization header is missing');
/// }
/// ```
class BloomUnauthorizedException extends BloomApiException {
  /// Creates a new [BloomUnauthorizedException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Unauthorized'`) and
  /// additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomUnauthorizedException('Token has expired', {'expired_at': '2026-01-01'});
  /// ```
  const BloomUnauthorizedException([
    String message = 'Unauthorized',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 401,
          message: message,
          errorCode: 'unauthorized',
          details: details,
        );
}

/// 403 Forbidden exception.
///
/// Thrown when the server understands the request but refuses to authorize it.
/// Unlike 401, authenticating will not make a difference (e.g. insufficient
/// permissions, locked accounts, path traversal attempts).
///
/// Example:
/// ```dart
/// if (!user.isAdmin) {
///   throw const BloomForbiddenException('Admin privileges required');
/// }
/// ```
class BloomForbiddenException extends BloomApiException {
  /// Creates a new [BloomForbiddenException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Forbidden'`) and
  /// additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomForbiddenException('Access denied to resource', {'resource_id': 99});
  /// ```
  const BloomForbiddenException([
    String message = 'Forbidden',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 403,
          message: message,
          errorCode: 'forbidden',
          details: details,
        );
}

/// 404 Not Found exception.
///
/// Thrown when the origin server did not find a current representation for the
/// target resource or is not willing to disclose that one exists.
///
/// Example:
/// ```dart
/// final user = await userRepository.findById(id);
/// if (user == null) {
///   throw BloomNotFoundException('User $id not found', {'user_id': id});
/// }
/// ```
class BloomNotFoundException extends BloomApiException {
  /// Creates a new [BloomNotFoundException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Not Found'`) and
  /// additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomNotFoundException('Project not found', {'project_id': 'proj_abc'});
  /// ```
  const BloomNotFoundException([
    String message = 'Not Found',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 404,
          message: message,
          errorCode: 'not_found',
          details: details,
        );
}

/// 409 Conflict exception.
///
/// Thrown when a request conflict with current state of the target resource
/// (e.g. unique constraint violations, concurrent state collisions).
///
/// Example:
/// ```dart
/// if (await userRepository.emailExists(email)) {
///   throw const BloomConflictException('A user with this email already exists');
/// }
/// ```
class BloomConflictException extends BloomApiException {
  /// Creates a new [BloomConflictException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Conflict'`) and
  /// additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomConflictException('Email already registered', {'email': 'user@example.com'});
  /// ```
  const BloomConflictException([
    String message = 'Conflict',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 409,
          message: message,
          errorCode: 'conflict',
          details: details,
        );
}

/// 422 Unprocessable Entity / Validation Failed exception.
///
/// Thrown when the server understands the content type and syntax of the request,
/// but was unable to process the contained instructions (e.g. semantic validation failure).
///
/// Example:
/// ```dart
/// throw BloomValidationFailedException(
///   message: 'Validation failed for user signup',
///   errors: {
///     'email': ['Must be a valid email address'],
///     'password': ['Must be at least 8 characters'],
///   },
/// );
/// ```
class BloomValidationFailedException extends BloomApiException {
  /// Creates a new [BloomValidationFailedException].
  ///
  /// Accepts a [message] (defaults to `'Validation Failed'`), an optional [errors]
  /// payload (e.g. a list or map of field-level errors), and additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomValidationFailedException(
  ///   errors: {'title': ['Title is required']},
  /// );
  /// ```
  BloomValidationFailedException({
    super.message = 'Validation Failed',
    dynamic errors,
    Map<String, dynamic>? details,
  }) : super(
          statusCode: 422,
          errorCode: 'validation_failed',
          details: {
            if (errors != null) 'errors': errors,
            ...?details,
          },
        );

  /// Convenient accessor for validation errors list/map if present.
  dynamic get errors => details?['errors'];
}

/// 429 Too Many Requests exception.
///
/// Thrown when the user has sent too many requests in a given amount of time
/// (rate limiting). Includes optional [retryAfter] duration.
///
/// Example:
/// ```dart
/// throw BloomTooManyRequestsException(
///   'Rate limit exceeded. Please retry in 60 seconds.',
///   const Duration(seconds: 60),
/// );
/// ```
class BloomTooManyRequestsException extends BloomApiException {
  /// Optional duration indicating how long to wait before making a new request.
  final Duration? retryAfter;

  /// Creates a new [BloomTooManyRequestsException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Too Many Requests'`),
  /// a [retryAfter] duration, and additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomTooManyRequestsException(
  ///   'Rate limit exceeded',
  ///   Duration(seconds: 30),
  /// );
  /// ```
  BloomTooManyRequestsException([
    String message = 'Too Many Requests',
    this.retryAfter,
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 429,
          message: message,
          errorCode: 'too_many_requests',
          details: {
            if (retryAfter != null) 'retry_after_seconds': retryAfter.inSeconds,
            ...?details,
          },
        );

  /// Converts this rate-limiting exception into a [BloomResponse].
  ///
  /// Automatically injects the `Retry-After` HTTP header with the duration in seconds
  /// if [retryAfter] is non-null, merging with any additional [headers] provided.
  @override
  BloomResponse toResponse({Map<String, String>? headers}) {
    final mergedHeaders = <String, String>{
      if (retryAfter != null) 'Retry-After': '${retryAfter!.inSeconds}',
      ...?headers,
    };
    return super.toResponse(headers: mergedHeaders);
  }
}

/// 500 Internal Server Error exception.
///
/// Thrown when the server encountered an unexpected condition that prevented it
/// from fulfilling the request.
///
/// Example:
/// ```dart
/// throw const BloomInternalException('Failed to initialize cache connection');
/// ```
class BloomInternalException extends BloomApiException {
  /// Creates a new [BloomInternalException].
  ///
  /// Optionally accepts a custom [message] (defaults to `'Internal Server Error'`)
  /// and additional structured [details].
  ///
  /// Example:
  /// ```dart
  /// throw BloomInternalException('Database query failed', {'query': 'SELECT ...'});
  /// ```
  const BloomInternalException([
    String message = 'Internal Server Error',
    Map<String, dynamic>? details,
  ]) : super(
          statusCode: 500,
          message: message,
          errorCode: 'internal_server_error',
          details: details,
        );
}
