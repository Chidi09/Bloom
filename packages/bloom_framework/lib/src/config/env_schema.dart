// lib/src/config/env_schema.dart
import '../core/env.dart';

/// Exception thrown when environment schema validation fails.
class BloomEnvironmentException implements Exception {
  /// Error summary message.
  final String message;

  /// Specific individual validation failure errors.
  final List<String> errors;

  /// Creates a [BloomEnvironmentException] with a [message] and optional [errors] list.
  BloomEnvironmentException(this.message, {this.errors = const []});

  @override
  String toString() => 'BloomEnvironmentException: $message';
}

/// Abstract base class for strictly typed and validated environment variable schemas.
abstract class BloomEnvironmentSchema {
  final List<String> _validationErrors = [];

  /// List of accumulated validation errors encountered during schema evaluation.
  List<String> get validationErrors => List.unmodifiable(_validationErrors);

  /// Evaluates and validates schema fields. Subclasses can override to evaluate `late` fields.
  void validate() {}

  /// Requires a non-empty string environment variable. Throws [BloomEnvironmentException] if missing.
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

  /// Reads an optional string environment variable with default fallback.
  String? optionalString(String key, {String? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    return val;
  }

  /// Requires a valid integer environment variable. Throws [BloomEnvironmentException] if missing or unparseable.
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

  /// Reads an optional integer environment variable.
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

  /// Requires a valid boolean environment variable. Throws [BloomEnvironmentException] if missing or invalid.
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

  /// Reads an optional boolean environment variable with default fallback.
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

  /// Requires a valid double environment variable.
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

  /// Reads an optional double environment variable.
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

  /// Requires a valid URI environment variable.
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

  /// Reads an optional URI environment variable.
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
