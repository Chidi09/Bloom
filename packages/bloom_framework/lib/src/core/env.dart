// lib/src/core/env.dart
import 'dart:collection';
import '../config/env_schema.dart';

/// Environment configuration parser and type-safe reader.
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

  /// Get environment variable string, fallback to compile-time define if not in map, or throw if absent.
  static String get(String key, {String? defaultValue}) {
    if (_env.containsKey(key)) {
      return _env[key]!;
    }
    if (bool.hasEnvironment(key)) {
      return String.fromEnvironment(key);
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    throw StateError('BloomEnv: Missing required environment variable "$key".');
  }

  /// Get environment variable string, or return `null` if not found.
  static String? getOrNull(String key) {
    if (_env.containsKey(key)) {
      return _env[key];
    }
    if (bool.hasEnvironment(key)) {
      return String.fromEnvironment(key);
    }
    return null;
  }

  /// Get integer value with dart-define fallback.
  static int getInt(String key, {int? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = int.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (bool.hasEnvironment(key)) {
      final fromDef = int.fromEnvironment(key);
      return fromDef;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError('BloomEnv: Missing required integer environment variable "$key".');
  }

  /// Get double value with dart-define fallback.
  static double getDouble(String key, {double? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = double.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (bool.hasEnvironment(key)) {
      final parsed = double.tryParse(String.fromEnvironment(key));
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError('BloomEnv: Missing required double environment variable "$key".');
  }

  /// Get boolean value with dart-define fallback.
  static bool getBool(String key, {bool? defaultValue}) {
    if (_env.containsKey(key)) {
      final val = _env[key]!;
      final lower = val.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (bool.hasEnvironment(key)) {
      return bool.fromEnvironment(key);
    }
    if (defaultValue != null) return defaultValue;
    throw StateError('BloomEnv: Missing required boolean environment variable "$key".');
  }

  /// Check if environment variable exists in map or dart-define environment.
  static bool contains(String key) => _env.containsKey(key) || bool.hasEnvironment(key);

  /// Check if environment variable exists (alias for contains).
  static bool has(String key) => contains(key);

  /// Clear all loaded environment variables.
  static void clear() => _env.clear();

  /// Read-only snapshot of all currently loaded environment variables.
  static Map<String, String> get all => UnmodifiableMapView(_env);
}
