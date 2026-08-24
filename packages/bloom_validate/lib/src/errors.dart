// lib/src/errors.dart
import 'package:bloom_server/bloom_server.dart';

/// Exception thrown when request body or DTO schema validation fails.
///
/// Encapsulates the primary error message along with an accumulated list of
/// validation failure strings collected during schema evaluation. Can be converted
/// directly into an HTTP JSON error response via [toResponse].
///
/// Example:
/// ```dart
/// try {
///   final schema = BloomRequestSchema.validateSchema(SignupSchema.fromRequest(request));
/// } on BloomValidationException catch (e) {
///   print('Primary error: ${e.message}');
///   print('All errors: ${e.errors.join(', ')}');
///   return e.toResponse();
/// }
/// ```
class BloomValidationException implements Exception {
  /// The primary validation failure message.
  final String message;

  /// The list of individual validation error messages collected during schema validation.
  final List<String> errors;

  /// Creates a [BloomValidationException] with a primary [message] and optional accumulated [errors].
  ///
  /// If [errors] is omitted or `null`, it defaults to a single-element list containing [message]
  /// (or an empty list if [message] is empty).
  ///
  /// Example:
  /// ```dart
  /// throw BloomValidationException(
  ///   'Validation failed',
  ///   errors: ['Field "email" is invalid', 'Field "age" must be >= 18'],
  /// );
  /// ```
  BloomValidationException(this.message, {List<String>? errors})
      : errors = errors ?? (message.isNotEmpty ? [message] : const []);

  /// Returns a human-readable string representation of this exception.
  @override
  String toString() => 'BloomValidationException: $message';

  /// Converts this validation exception into a structured 400 Bad Request [BloomResponse].
  ///
  /// The response payload contains a JSON map with `error`, `errors`, and `statusCode` fields.
  /// The [statusCode] defaults to `400` (Bad Request).
  ///
  /// Example:
  /// ```dart
  /// on BloomValidationException catch (e) {
  ///   return e.toResponse(); // HTTP 400 with {"error": "...", "errors": [...], "statusCode": 400}
  /// }
  /// ```
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


