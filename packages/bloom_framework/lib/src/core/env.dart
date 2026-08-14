// lib/src/core/env.dart
import 'dart:collection';

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

  /// Get environment variable string, or throw if not present and no default provided.
  static String get(String key, {String? defaultValue}) {
    final val = _env[key] ?? defaultValue;
    if (val == null) {
      throw StateError('BloomEnv: Missing required environment variable "$key".');
    }
    return val;
  }

  /// Get environment variable string, or return `null` if not found.
  static String? getOrNull(String key) {
    return _env[key];
  }

  /// Get integer value.
  static int getInt(String key, {int? defaultValue}) {
    final val = _env[key];
    if (val == null) {
      if (defaultValue != null) return defaultValue;
      throw StateError('BloomEnv: Missing required integer environment variable "$key".');
    }
    final parsed = int.tryParse(val);
    if (parsed == null) {
      if (defaultValue != null) return defaultValue;
      throw FormatException('BloomEnv: "$key" is not a valid integer: "$val"');
    }
    return parsed;
  }

  /// Get double value.
  static double getDouble(String key, {double? defaultValue}) {
    final val = _env[key];
    if (val == null) {
      if (defaultValue != null) return defaultValue;
      throw StateError('BloomEnv: Missing required double environment variable "$key".');
    }
    final parsed = double.tryParse(val);
    if (parsed == null) {
      if (defaultValue != null) return defaultValue;
      throw FormatException('BloomEnv: "$key" is not a valid double: "$val"');
    }
    return parsed;
  }

  /// Get boolean value.
  static bool getBool(String key, {bool? defaultValue}) {
    final val = _env[key];
    if (val == null) {
      if (defaultValue != null) return defaultValue;
      throw StateError('BloomEnv: Missing required boolean environment variable "$key".');
    }
    final lower = val.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
    if (defaultValue != null) return defaultValue;
    throw FormatException('BloomEnv: "$key" is not a valid boolean: "$val"');
  }

  /// Check if environment variable exists.
  static bool contains(String key) => _env.containsKey(key);

  /// Check if environment variable exists (alias for contains).
  static bool has(String key) => contains(key);

  /// Clear all loaded environment variables.
  static void clear() => _env.clear();

  /// Read-only snapshot of all currently loaded environment variables.
  static Map<String, String> get all => UnmodifiableMapView(_env);
}
