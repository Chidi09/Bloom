// lib/src/http_exception.dart
import 'package:bloom_framework/bloom_server.dart';

/// Base abstract class for all strongly-typed HTTP exceptions in the Bloom framework.
///
/// Subclasses carry an HTTP [statusCode], a human-readable [message], a machine-readable
/// [errorCode] (e.g. `"not_found"`, `"unauthorized"`), and optional structured [details].
abstract class BloomApiException implements Exception {
  /// HTTP status code (e.g. 404, 401, 500).
  final int statusCode;

  /// Human-readable explanation of the error.
  final String message;

  /// Short machine-readable string identifier for the error category.
  final String? errorCode;

  /// Additional structured context, field validation errors, or debug info.
  final Map<String, dynamic>? details;

  const BloomApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.details,
  });

  /// Serializes the error into a structured JSON map.
  Map<String, dynamic> toJson() {
    return {
      'code': errorCode ?? 'error',
      'message': message,
      if (details != null && details!.isNotEmpty) 'details': details,
    };
  }

  /// Converts this exception directly into a formatted [BloomResponse].
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
class BloomBadRequestException extends BloomApiException {
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
class BloomUnauthorizedException extends BloomApiException {
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
class BloomForbiddenException extends BloomApiException {
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
class BloomNotFoundException extends BloomApiException {
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
class BloomConflictException extends BloomApiException {
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
class BloomValidationFailedException extends BloomApiException {
  BloomValidationFailedException({
    String message = 'Validation Failed',
    dynamic errors,
    Map<String, dynamic>? details,
  }) : super(
          statusCode: 422,
          message: message,
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
class BloomTooManyRequestsException extends BloomApiException {
  final Duration? retryAfter;

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
class BloomInternalException extends BloomApiException {
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
