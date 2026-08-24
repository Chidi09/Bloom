// lib/src/config/env_schema.dart
import '../core/env.dart';

/// Exception thrown when environment schema validation fails or a required variable is missing/invalid.
///
/// Contains an overall descriptive [message] and a list of individual [errors] detailing
/// each failed environment variable requirement.
///
/// ### Example
/// ```dart
/// try {
///   BloomEnv.validate(AppConfig());
/// } on BloomEnvironmentException catch (e) {
///   print('Config error: ${e.message}');
///   for (final err in e.errors) {
///     print(' - $err');
///   }
/// }
/// ```
class BloomEnvironmentException implements Exception {
  /// Error summary message describing the validation failure.
  final String message;

  /// Specific individual validation failure error messages.
  final List<String> errors;

  /// Creates a [BloomEnvironmentException] with a [message] and optional [errors] list.
  BloomEnvironmentException(this.message, {this.errors = const []});

  @override
  String toString() => 'BloomEnvironmentException: $message';
}

/// Abstract base class for strictly typed and validated environment variable schemas.
///
/// Subclass [BloomEnvironmentSchema] to define your application's required and optional
/// configuration variables with type parsing and descriptions.
///
/// ### Example
/// ```dart
/// class AppConfig extends BloomEnvironmentSchema {
///   late final String appEnv = optionalString('APP_ENV', defaultValue: 'development')!;
///   late final int port = optionalInt('PORT', defaultValue: 8080);
///   late final String databaseUrl = requireString('DATABASE_URL', description: 'Postgres connection string');
///   late final bool debug = optionalBool('DEBUG', defaultValue: false);
///   late final Uri apiBase = requireUri('API_BASE_URL', description: 'Upstream API endpoint');
///
///   @override
///   void validate() {
///     // Force evaluation of late fields to trigger validation
///     appEnv;
///     port;
///     databaseUrl;
///     debug;
///     apiBase;
///   }
/// }
///
/// void main() {
///   BloomEnv.loadContent('DATABASE_URL=postgres://localhost:5432/db\nAPI_BASE_URL=https://api.example.com');
///   final config = BloomEnv.validate(AppConfig());
///   print('Connected to: ${config.databaseUrl} on port ${config.port}');
/// }
/// ```
abstract class BloomEnvironmentSchema {
  final List<String> _validationErrors = [];

  /// List of accumulated validation errors encountered during schema evaluation.
  List<String> get validationErrors => List.unmodifiable(_validationErrors);

  /// Evaluates and validates schema fields. Subclasses can override to evaluate `late` fields.
  void validate() {}

  /// Requires a non-empty string environment variable identified by [key].
  ///
  /// Appends [description] to the error message if provided.
  /// Throws [BloomEnvironmentException] if the variable is missing or empty.
  String requireString(String key, {String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      final err = 'Missing required environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return val;
  }

  /// Reads an optional string environment variable identified by [key].
  ///
  /// Returns [defaultValue] if the variable is not set or empty.
  /// [description] provides optional context for documentation.
  String? optionalString(String key, {String? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    return val;
  }

  /// Requires a valid integer environment variable identified by [key].
  ///
  /// Appends [description] to the error message if provided.
  /// Throws [BloomEnvironmentException] if the variable is missing, empty, or cannot be parsed as an integer.
  int requireInt(String key, {String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      final err = 'Missing required integer environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final parsed = int.tryParse(val);
    if (parsed == null) {
      final err = 'Environment variable "$key" is not a valid integer: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Reads an optional integer environment variable identified by [key].
  ///
  /// Returns [defaultValue] (or `0` if [defaultValue] is null) when the variable is unset or empty.
  /// Throws [BloomEnvironmentException] if the variable is present but not a valid integer string.
  int optionalInt(String key, {int? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue ?? 0;
    }
    final parsed = int.tryParse(val);
    if (parsed == null) {
      final err = 'Environment variable "$key" is not a valid integer: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Requires a valid boolean environment variable identified by [key].
  ///
  /// Accepts `'true'`, `'1'`, `'yes'` (case-insensitive) as `true`,
  /// and `'false'`, `'0'`, `'no'` as `false`.
  /// Throws [BloomEnvironmentException] if missing, empty, or unparseable.
  bool requireBool(String key, {String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      final err = 'Missing required boolean environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;

    final err = 'Environment variable "$key" is not a valid boolean: "$val".';
    _validationErrors.add(err);
    throw BloomEnvironmentException(err, errors: [err]);
  }

  /// Reads an optional boolean environment variable identified by [key].
  ///
  /// Returns [defaultValue] (default `false`) if the variable is unset or empty.
  /// Accepts `'true'`, `'1'`, `'yes'` as `true`, and `'false'`, `'0'`, `'no'` as `false`.
  /// Throws [BloomEnvironmentException] if the variable is present but cannot be parsed as a boolean.
  bool optionalBool(String key, {bool defaultValue = false, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;

    final err = 'Environment variable "$key" is not a valid boolean: "$val".';
    _validationErrors.add(err);
    throw BloomEnvironmentException(err, errors: [err]);
  }

  /// Requires a valid double environment variable identified by [key].
  ///
  /// Appends [description] to the error message if provided.
  /// Throws [BloomEnvironmentException] if missing, empty, or cannot be parsed as a double.
  double requireDouble(String key, {String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      final err = 'Missing required double environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final parsed = double.tryParse(val);
    if (parsed == null) {
      final err = 'Environment variable "$key" is not a valid double: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Reads an optional double environment variable identified by [key].
  ///
  /// Returns [defaultValue] (or `0.0` if null) if unset or empty.
  /// Throws [BloomEnvironmentException] if the variable is present but cannot be parsed as a double.
  double optionalDouble(String key, {double? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue ?? 0.0;
    }
    final parsed = double.tryParse(val);
    if (parsed == null) {
      final err = 'Environment variable "$key" is not a valid double: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Requires a valid absolute URI environment variable identified by [key].
  ///
  /// Validates that the URI is parseable and contains a scheme (e.g. `https://...`).
  /// Throws [BloomEnvironmentException] if missing, empty, or invalid.
  Uri requireUri(String key, {String? description}) {
    final str = requireString(key, description: description);
    final parsed = Uri.tryParse(str);
    if (parsed == null || !parsed.hasScheme) {
      final err = 'Environment variable "$key" is not a valid absolute URI: "$str".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Reads an optional URI environment variable identified by [key].
  ///
  /// Returns [defaultValue] if unset or empty.
  /// Throws [BloomEnvironmentException] if the variable is present but cannot be parsed as a URI.
  Uri? optionalUri(String key, {Uri? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    final parsed = Uri.tryParse(val);
    if (parsed == null) {
      final err = 'Environment variable "$key" is not a valid URI: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }
}

