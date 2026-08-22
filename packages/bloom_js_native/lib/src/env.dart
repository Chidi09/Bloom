// lib/src/env.dart
import 'dart:collection';

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
  String? optionalString(String key,
      {String? defaultValue, String? description}) {
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
      final err =
          'Missing required integer environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final parsed = int.tryParse(val);
    if (parsed == null) {
      final err =
          'Environment variable "$key" is not a valid integer: "$val".';
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
      final err =
          'Environment variable "$key" is not a valid integer: "$val".';
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
      final err =
          'Missing required boolean environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;

    final err =
        'Environment variable "$key" is not a valid boolean: "$val".';
    _validationErrors.add(err);
    throw BloomEnvironmentException(err, errors: [err]);
  }

  /// Reads an optional boolean environment variable with default fallback.
  bool optionalBool(String key,
      {bool defaultValue = false, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;

    final err =
        'Environment variable "$key" is not a valid boolean: "$val".';
    _validationErrors.add(err);
    throw BloomEnvironmentException(err, errors: [err]);
  }

  /// Requires a valid double environment variable.
  double requireDouble(String key, {String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      final err =
          'Missing required double environment variable "$key"$desc.';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    final parsed = double.tryParse(val);
    if (parsed == null) {
      final err =
          'Environment variable "$key" is not a valid double: "$val".';
      _validationErrors.add(err);
      throw BloomEnvironmentException(err, errors: [err]);
    }
    return parsed;
  }

  /// Reads an optional double environment variable.
  double optionalDouble(String key,
      {double? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue ?? 0.0;
    }
    final parsed = double.tryParse(val);
    if (parsed == null) {
      final err =
          'Environment variable "$key" is not a valid double: "$val".';
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
      final err =
          'Environment variable "$key" is not a valid absolute URI: "$str".';
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

/// Environment configuration parser and type-safe reader.
/// Pure-Dart, zero Flutter SDK dependency.
class BloomEnv {
  static final Map<String, String> _env = HashMap<String, String>();

  /// Load and parse `.env` formatted content string.
  static void loadContent(String content, {bool overwrite = true}) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final eqIdx = line.indexOf('=');
      if (eqIdx == -1) continue;

      final key = line.substring(0, eqIdx).trim();
      var value = line.substring(eqIdx + 1).trim();

      // Strip surrounding quotes
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }

      if (overwrite || !_env.containsKey(key)) {
        _env[key] = value;
      }
    }
  }

  /// Populate environment variables directly from a Map.
  static void loadMap(Map<String, String> map, {bool overwrite = true}) {
    map.forEach((k, v) {
      if (overwrite || !_env.containsKey(k)) {
        _env[k] = v;
      }
    });
  }

  /// Seeds `--dart-define` values into the runtime map.
  ///
  /// `String.fromEnvironment`/`bool.hasEnvironment` are const constructors —
  /// Dart only resolves them for literal keys known at compile time.
  /// Callers declare their known dart-define keys as literals here:
  ///
  /// ```dart
  /// BloomEnv.loadDartDefines({
  ///   if (const bool.hasEnvironment('APP_ENV'))
  ///     'APP_ENV': const String.fromEnvironment('APP_ENV'),
  /// });
  /// ```
  static void loadDartDefines(Map<String, String> defines,
          {bool overwrite = false}) =>
      loadMap(defines, overwrite: overwrite);

  /// Validates a typed [BloomEnvironmentSchema] against current environment variables.
  /// Throws [BloomEnvironmentException] if any required keys are missing or malformed.
  static T validate<T extends BloomEnvironmentSchema>(T schema) {
    schema.validate();
    if (schema.validationErrors.isNotEmpty) {
      throw BloomEnvironmentException(
        'Environment schema validation failed: ${schema.validationErrors.join("; ")}',
        errors: schema.validationErrors,
      );
    }
    return schema;
  }

  /// Get environment variable string, fallback to default if provided, or throw if absent.
  static String get(String key, {String? defaultValue}) {
    if (_env.containsKey(key)) {
      return _env[key]!;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    throw StateError(
        'BloomEnv: Missing required environment variable "$key".');
  }

  /// Get environment variable string, or return `null` if not found.
  static String? getOrNull(String key) => _env[key];

  /// Get integer value.
  static int getInt(String key, {int? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = int.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required integer environment variable "$key".');
  }

  /// Get double value.
  static double getDouble(String key, {double? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = double.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required double environment variable "$key".');
  }

  /// Get boolean value.
  static bool getBool(String key, {bool? defaultValue}) {
    if (_env.containsKey(key)) {
      final val = _env[key]!;
      final lower = val.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required boolean environment variable "$key".');
  }

  /// Check if environment variable exists in the runtime map.
  static bool contains(String key) => _env.containsKey(key);

  /// Check if environment variable exists (alias for contains).
  static bool has(String key) => contains(key);

  /// Clear all loaded environment variables.
  static void clear() => _env.clear();

  /// Read-only snapshot of all currently loaded environment variables.
  static Map<String, String> get all => UnmodifiableMapView(_env);
}
