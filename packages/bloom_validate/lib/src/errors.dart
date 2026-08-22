// lib/src/errors.dart
import 'package:bloom_server/bloom_server.dart';

/// Exception thrown when request body or DTO schema validation fails.
///
/// Holds the primary [message] and a list of all accumulated [errors] collected
/// during schema evaluation.
class BloomValidationException implements Exception {
  /// The primary validation failure message.
  final String message;

  /// The list of individual validation error messages collected during schema validation.
  final List<String> errors;

  /// Creates a [BloomValidationException] with a primary [message] and optional accumulated [errors].
  BloomValidationException(this.message, {List<String>? errors})
      : errors = errors ?? (message.isNotEmpty ? [message] : const []);

  @override
  String toString() => 'BloomValidationException: $message';

  /// Converts this validation exception into a structured 400 Bad Request [BloomResponse].
  ///
  /// The [statusCode] defaults to `400`.
  BloomResponse toResponse({int statusCode = 400}) {
    return BloomResponse.json(
      {
        'error': message,
        'errors': errors.isNotEmpty ? errors : [message],
        'statusCode': statusCode,
      },
      statusCode: statusCode,
    );
  }
}

