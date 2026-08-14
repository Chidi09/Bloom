// lib/src/core/env.dart
import 'dart:collection';

/// Environment variable loader and parser for Bloom applications.
/// Supports `.env`, `.env.local`, and inline variable parsing.
class BloomEnv {
  static final Map<String, String> _env = HashMap<String, String>();
  static bool _isLoaded = false;

  /// Whether environment variables have been loaded.
  static bool get isLoaded => _isLoaded;

  /// Unmodifiable view of all loaded environment variables.
  static Map<String, String> get all => UnmodifiableMapView(_env);

  /// Load and parse environment string content.
  static void loadContent(String content, {bool overwrite = true}) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final equalsIndex = line.indexOf('=');
      if (equalsIndex == -1) continue;

      final key = line.substring(0, equalsIndex).trim();
      var value = line.substring(equalsIndex + 1).trim();

      // Remove surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }

      if (key.isNotEmpty) {
        if (overwrite || !_env.containsKey(key)) {
          _env[key] = value;
        }
      }
    }
    _isLoaded = true;
  }

  /// Get an environment variable as a [String], or return [defaultValue] if null/missing.
  static String? get(String key, {String? defaultValue}) {
    return _env[key] ?? defaultValue;
  }

  /// Get a non-null [String] or throw a [StateError] if missing.
  static String getRequired(String key) {
    final val = _env[key];
    if (val == null) {
      throw StateError('Missing required environment variable: "$key"');
    }
    return val;
  }

  /// Get an environment variable parsed as an [int].
  static int? getInt(String key, {int? defaultValue}) {
    final val = _env[key];
    if (val == null) return defaultValue;
    return int.tryParse(val) ?? defaultValue;
  }

  /// Get an environment variable parsed as a [double].
  static double? getDouble(String key, {double? defaultValue}) {
    final val = _env[key];
    if (val == null) return defaultValue;
    return double.tryParse(val) ?? defaultValue;
  }

  /// Get an environment variable parsed as a [bool].
  /// Matches 'true', '1', 'yes', 'on' (case-insensitive).
  static bool? getBool(String key, {bool? defaultValue}) {
    final val = _env[key];
    if (val == null) return defaultValue;
    final lower = val.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on') {
      return true;
    }
    if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'off') {
      return false;
    }
    return defaultValue;
  }

  /// Check if a variable key is defined.
  static bool has(String key) => _env.containsKey(key);

  /// Set a key-value pair directly (useful for tests or dynamic runtime injection).
  static void set(String key, String value) {
    _env[key] = value;
    _isLoaded = true;
  }

  /// Clear all loaded environment variables.
  static void clear() {
    _env.clear();
    _isLoaded = false;
  }
}
