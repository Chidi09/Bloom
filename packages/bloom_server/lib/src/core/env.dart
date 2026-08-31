// lib/src/core/env.dart
import 'dart:collection';
import '../config/env_schema.dart';

/// Environment configuration parser, store, and type-safe reader.
///
/// [BloomEnv] provides a centralized, in-memory environment configuration store:
/// - **Parsing**: Load configuration from raw `.env` files via [loadContent] or from Dart maps via [loadMap].
/// - **Compile-Time Defines**: Seed `--dart-define` constants using [loadDartDefines].
/// - **Type-Safe Accessors**: Retrieve values typed as [String], [int], [double], or [bool]
///   with optional defaults or strict exception throwing on missing values.
/// - **Schema Validation**: Validate strongly-typed configurations with [validate] and [BloomEnvironmentSchema].
///
/// ### Example
/// ```dart
/// // 1. Load from .env text
/// BloomEnv.loadContent('''
///   APP_PORT=8080
///   DEBUG=true
///   DB_HOST=127.0.0.1
/// ''');
///
/// // 2. Read typed values
/// final port = BloomEnv.getInt('APP_PORT', defaultValue: 3000);
/// final isDebug = BloomEnv.getBool('DEBUG');
/// final dbHost = BloomEnv.get('DB_HOST');
/// ```
class BloomEnv {
  static final Map<String, String> _env = HashMap<String, String>();

  /// Parses and loads environment variables from a raw `.env` formatted [content] string.
  ///
  /// Ignores blank lines and comments starting with `#`. Strips surrounding single
  /// (`'`) or double (`"`) quotes from values.
  ///
  /// If [overwrite] is `true` (the default), existing keys are overwritten; otherwise,
  /// previously loaded values are preserved.
  ///
  /// ### Example
  /// ```dart
  /// BloomEnv.loadContent('PORT=8080\nAPI_KEY="secret_key"');
  /// ```
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

  /// Populates environment variables directly from a [map] of key-value pairs.
  ///
  /// If [overwrite] is `true` (the default), existing keys are overwritten.
  ///
  /// ### Example
  /// ```dart
  /// BloomEnv.loadMap({'PORT': '8080', 'HOST': '0.0.0.0'});
  /// ```
  static void loadMap(Map<String, String> map, {bool overwrite = true}) {
    map.forEach((k, v) {
      if (overwrite || !_env.containsKey(k)) {
        _env[k] = v;
      }
    });
  }

  /// Seeds `--dart-define` values into the runtime environment map.
  ///
  /// `String.fromEnvironment`/`bool.hasEnvironment` are const constructors —
  /// Dart only resolves them for literal keys known at compile time, so
  /// `BloomEnv` cannot look a dart-define up generically by a runtime [defines] key.
  /// Callers declare their known dart-define keys as literals here, and every other
  /// `BloomEnv` accessor can then read them back out of the ordinary runtime map.
  ///
  /// If [overwrite] is `true`, passed definitions override existing keys (default is `false`).
  ///
  /// ### Example
  /// ```dart
  /// BloomEnv.loadDartDefines({
  ///   if (const bool.hasEnvironment('APP_ENV'))
  ///     'APP_ENV': const String.fromEnvironment('APP_ENV'),
  ///   if (const bool.hasEnvironment('PORT'))
  ///     'PORT': const String.fromEnvironment('PORT'),
  /// });
  /// ```
  static void loadDartDefines(Map<String, String> defines,
          {bool overwrite = false}) =>
      loadMap(defines, overwrite: overwrite);

  /// Validates a typed [BloomEnvironmentSchema] instance against the currently loaded environment variables.
  ///
  /// Calls [BloomEnvironmentSchema.validate] and returns the [schema] instance if valid.
  /// Throws [BloomEnvironmentException] if any required keys are missing or unparseable.
  ///
  /// ### Example
  /// ```dart
  /// final config = BloomEnv.validate(MyConfigSchema());
  /// ```
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

  /// Retrieves the string value for [key].
  ///
  /// Returns [defaultValue] if [key] is absent and [defaultValue] is provided.
  /// Throws [StateError] if [key] is not found and no [defaultValue] is given.
  static String get(String key, {String? defaultValue}) {
    if (_env.containsKey(key)) {
      return _env[key]!;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    throw StateError('BloomEnv: Missing required environment variable "$key".');
  }

  /// Retrieves the string value for [key], or returns `null` if not found.
  static String? getOrNull(String key) => _env[key];

  /// Retrieves the integer value for [key].
  ///
  /// Parses the string value as an [int]. Returns [defaultValue] if [key] is absent.
  /// Throws [StateError] if [key] is absent and no [defaultValue] is provided, or if
  /// the value cannot be parsed as an integer.
  static int getInt(String key, {int? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = int.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required integer environment variable "$key".');
  }

  /// Retrieves the double value for [key].
  ///
  /// Parses the string value as a [double]. Returns [defaultValue] if [key] is absent.
  /// Throws [StateError] if [key] is absent and no [defaultValue] is provided, or if
  /// the value cannot be parsed as a double.
  static double getDouble(String key, {double? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = double.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required double environment variable "$key".');
  }

  /// Retrieves the boolean value for [key].
  ///
  /// Accepts `'true'`, `'1'`, `'yes'` (case-insensitive) as `true`,
  /// and `'false'`, `'0'`, `'no'` as `false`.
  /// Returns [defaultValue] if [key] is absent.
  /// Throws [StateError] if [key] is absent and no [defaultValue] is provided, or if
  /// the value cannot be parsed as a valid boolean representation.
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

  /// Checks whether an environment variable exists in the runtime store for [key].
  static bool contains(String key) => _env.containsKey(key);

  /// Checks whether an environment variable exists in the runtime store for [key].
  ///
  /// Alias for [contains].
  static bool has(String key) => contains(key);

  /// Clears all loaded environment variables from the internal in-memory store.
  static void clear() => _env.clear();

  /// A read-only snapshot map of all currently loaded environment variables.
  static Map<String, String> get all => UnmodifiableMapView(_env);
}
