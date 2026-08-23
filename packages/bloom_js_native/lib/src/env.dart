// lib/src/env.dart
import 'dart:collection';

/// Exception thrown when environment schema validation or variable parsing fails.
///
/// Contains a summary [message] and a list of specific individual [errors] encountered
/// during schema evaluation by [BloomEnvironmentSchema] and [BloomEnv.validate].
///
/// ```dart
/// try {
///   BloomEnv.validate(AppSchema());
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

  /// Specific individual validation failure errors accumulated during schema evaluation.
  final List<String> errors;

  /// Creates a [BloomEnvironmentException] with a summary [message] and optional [errors] list.
  BloomEnvironmentException(this.message, {this.errors = const []});

  @override
  String toString() => 'BloomEnvironmentException: $message';
}

/// Abstract base class for defining strictly typed and validated environment variable schemas.
///
/// Subclasses declare strongly-typed configuration properties using schema helper methods
/// like [requireString], [optionalInt], [requireBool], and [requireUri]. When validated
/// via [BloomEnv.validate], any missing required keys or malformed values are collected
/// into [validationErrors] and thrown as a [BloomEnvironmentException].
///
/// ### Backend Behavior
/// - **SSR & VM**: Evaluated during server bootstrap before serving requests.
/// - **Browser**: Evaluated during client startup after loading embedded configs or `--dart-define` constants.
///
/// ### Example
/// ```dart
/// class AppConfig extends BloomEnvironmentSchema {
///   late final String apiUrl = requireString('API_URL', description: 'Backend API base URL');
///   late final int port = optionalInt('PORT', defaultValue: 8080);
///   late final bool debugMode = optionalBool('DEBUG', defaultValue: false);
///   late final Uri authEndpoint = requireUri('AUTH_URL');
///
///   @override
///   void validate() {
///     // Trigger evaluation of late fields to collect any errors
///     apiUrl;
///     port;
///     debugMode;
///     authEndpoint;
///   }
/// }
///
/// void main() {
///   BloomEnv.loadContent('API_URL=https://api.example.com\nAUTH_URL=https://auth.example.com');
///   final config = BloomEnv.validate(AppConfig());
///   print('Port: ${config.port}');
/// }
/// ```
///
/// See also:
/// - [BloomEnv.validate], the validator function that evaluates a schema.
/// - [BloomEnvironmentException], thrown when validation fails.
abstract class BloomEnvironmentSchema {
  final List<String> _validationErrors = [];

  /// An unmodifiable list of accumulated validation errors encountered during schema evaluation.
  List<String> get validationErrors => List.unmodifiable(_validationErrors);

  /// Evaluates and validates schema fields.
  ///
  /// Subclasses should override this method to touch all `late` schema fields so that
  /// validation exceptions are captured during [BloomEnv.validate].
  ///
  /// ```dart
  /// @override
  /// void validate() {
  ///   apiUrl;
  ///   timeoutSeconds;
  /// }
  /// ```
  void validate() {}

  /// Reads a required non-empty string environment variable.
  ///
  /// Retrieves [key] from [BloomEnv], trimming leading and trailing whitespace.
  /// Throws [BloomEnvironmentException] and records a failure in [validationErrors]
  /// if the key is absent or empty.
  ///
  /// [description] optionally adds human-readable context to the error message.
  ///
  /// ```dart
  /// late final String apiKey = requireString('API_KEY', description: 'Secret API Key');
  /// ```
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

  /// Reads an optional string environment variable, falling back to [defaultValue].
  ///
  /// Retrieves [key] from [BloomEnv], trimming whitespace. If the key is absent or empty,
  /// returns [defaultValue] (which defaults to `null`).
  ///
  /// ```dart
  /// late final String? cdnHost = optionalString('CDN_HOST', defaultValue: 'https://cdn.example.com');
  /// ```
  String? optionalString(String key,
      {String? defaultValue, String? description}) {
    final val = BloomEnv.getOrNull(key)?.trim();
    if (val == null || val.isEmpty) {
      return defaultValue;
    }
    return val;
  }

  /// Reads a required integer environment variable.
  ///
  /// Retrieves [key] from [BloomEnv] and parses it with [int.tryParse].
  /// Throws [BloomEnvironmentException] and records an error in [validationErrors]
  /// if the key is missing, empty, or cannot be parsed as an integer.
  ///
  /// ```dart
  /// late final int maxRetries = requireInt('MAX_RETRIES');
  /// ```
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

  /// Reads an optional integer environment variable, falling back to [defaultValue] or `0`.
  ///
  /// Retrieves [key] from [BloomEnv]. If absent or blank, returns [defaultValue] ?? `0`.
  /// If present but not a valid integer, throws [BloomEnvironmentException] and records an error in [validationErrors].
  ///
  /// ```dart
  /// late final int timeoutMs = optionalInt('TIMEOUT_MS', defaultValue: 5000);
  /// ```
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

  /// Reads a required boolean environment variable.
  ///
  /// Case-insensitively parses the value:
  /// - `true`: `"true"`, `"1"`, `"yes"`
  /// - `false`: `"false"`, `"0"`, `"no"`
  ///
  /// Throws [BloomEnvironmentException] and records an error in [validationErrors]
  /// if the key is missing, blank, or has any other string value.
  ///
  /// ```dart
  /// late final bool enableSsl = requireBool('ENABLE_SSL');
  /// ```
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
  ///
  /// Case-insensitively parses `"true"`, `"1"`, `"yes"` as `true`, and `"false"`, `"0"`, `"no"` as `false`.
  /// If the variable is absent or blank, returns [defaultValue] (defaults to `false`).
  /// If present but unrecognized, throws [BloomEnvironmentException].
  ///
  /// ```dart
  /// late final bool analyticsEnabled = optionalBool('ENABLE_ANALYTICS', defaultValue: true);
  /// ```
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

  /// Reads a required double-precision floating-point environment variable.
  ///
  /// Retrieves [key] from [BloomEnv] and parses it via [double.tryParse].
  /// Throws [BloomEnvironmentException] and records an error in [validationErrors]
  /// if missing, blank, or unparseable.
  ///
  /// ```dart
  /// late final double samplingRate = requireDouble('SAMPLE_RATE');
  /// ```
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

  /// Reads an optional double environment variable, falling back to [defaultValue] or `0.0`.
  ///
  /// If absent or blank, returns [defaultValue] ?? `0.0`.
  /// If present but invalid, throws [BloomEnvironmentException].
  ///
  /// ```dart
  /// late final double threshold = optionalDouble('ALERT_THRESHOLD', defaultValue: 0.75);
  /// ```
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

  /// Reads a required absolute URI environment variable.
  ///
  /// Validates that the parsed [Uri] has a scheme (e.g. `http`, `https`, `wss`).
  /// Throws [BloomEnvironmentException] if the variable is missing, blank, unparseable,
  /// or lacks a valid URI scheme.
  ///
  /// ```dart
  /// late final Uri databaseUri = requireUri('DATABASE_URL');
  /// ```
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

  /// Reads an optional URI environment variable, falling back to [defaultValue].
  ///
  /// If absent or blank, returns [defaultValue] (which defaults to `null`).
  /// If present but cannot be parsed as a [Uri], throws [BloomEnvironmentException].
  ///
  /// ```dart
  /// late final Uri? webhook = optionalUri('SLACK_WEBHOOK_URL');
  /// ```
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

/// Environment configuration store, parser, and type-safe reader for Bloom JS Native applications.
///
/// [BloomEnv] manages runtime environment variables from multiple sources:
/// - Parsing `.env` files via [loadContent].
/// - Dynamic configuration maps via [loadMap].
/// - Compile-time `--dart-define` constants via [loadDartDefines].
///
/// ### Accessing Variables
/// - Strongly-typed schema validation via [validate] (recommended).
/// - Direct typed getters ([get], [getInt], [getDouble], [getBool]) which throw [StateError] on missing keys without defaults.
/// - Safe nullable lookup via [getOrNull].
///
/// ### SSR & Browser Compatibility
/// Pure Dart with zero Flutter or DOM dependencies. Works identically during server-side rendering
/// (SSR), Dart VM execution, and client-side web browser execution.
///
/// ### Example
/// ```dart
/// // 1. Load configuration from a .env file content
/// BloomEnv.loadContent('''
/// API_BASE_URL=https://api.bloom.dev
/// PORT=8080
/// DEBUG=true
/// ''');
///
/// // 2. Read values directly
/// final apiUrl = BloomEnv.get('API_BASE_URL');
/// final port = BloomEnv.getInt('PORT', defaultValue: 3000);
/// final isDebug = BloomEnv.getBool('DEBUG', defaultValue: false);
/// ```
class BloomEnv {
  static final Map<String, String> _env = HashMap<String, String>();

  /// Parses a raw `.env` formatted content string and loads the resulting key-value pairs into the runtime map.
  ///
  /// Ignores blank lines and comment lines starting with `#`. Strips matching surrounding single or double quotes
  /// from values.
  ///
  /// When [overwrite] is `true` (the default), existing keys in the environment map are replaced.
  /// When `false`, previously set keys are preserved.
  ///
  /// ```dart
  /// BloomEnv.loadContent('API_KEY="secret_key_123"\n# Comment\nPORT=9000');
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

  /// Populates environment variables directly from a key-value [map].
  ///
  /// When [overwrite] is `true` (the default), existing keys are replaced.
  /// When `false`, existing values are kept.
  ///
  /// ```dart
  /// BloomEnv.loadMap({'APP_NAME': 'BloomApp', 'STAGE': 'staging'});
  /// ```
  static void loadMap(Map<String, String> map, {bool overwrite = true}) {
    map.forEach((k, v) {
      if (overwrite || !_env.containsKey(k)) {
        _env[k] = v;
      }
    });
  }

  /// Seeds `--dart-define` compile-time constants into the runtime environment map.
  ///
  /// Because `String.fromEnvironment` and `bool.hasEnvironment` are `const` constructors in Dart,
  /// keys must be declared as compile-time string literals at the call site.
  ///
  /// By default, [overwrite] is `false` so runtime `.env` values or dynamic maps take precedence.
  ///
  /// ```dart
  /// BloomEnv.loadDartDefines({
  ///   if (const bool.hasEnvironment('API_BASE_URL'))
  ///     'API_BASE_URL': const String.fromEnvironment('API_BASE_URL'),
  ///   if (const bool.hasEnvironment('APP_ENV'))
  ///     'APP_ENV': const String.fromEnvironment('APP_ENV'),
  /// });
  /// ```
  static void loadDartDefines(Map<String, String> defines,
          {bool overwrite = false}) =>
      loadMap(defines, overwrite: overwrite);

  /// Validates a typed [BloomEnvironmentSchema] against current environment variables.
  ///
  /// Calls [BloomEnvironmentSchema.validate] on [schema]. If any validation errors occurred,
  /// throws a [BloomEnvironmentException] containing the accumulated errors. Otherwise returns
  /// the validated [schema] instance.
  ///
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
  /// If [key] exists in the environment map, returns its value.
  /// If missing and [defaultValue] is provided, returns [defaultValue].
  /// If missing and no [defaultValue] is provided, throws a [StateError].
  ///
  /// ```dart
  /// final host = BloomEnv.get('HOST', defaultValue: 'localhost');
  /// ```
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

  /// Retrieves the string value for [key], or returns `null` if [key] is absent.
  ///
  /// Does not throw if the key is missing.
  ///
  /// ```dart
  /// final proxy = BloomEnv.getOrNull('HTTP_PROXY');
  /// ```
  static String? getOrNull(String key) => _env[key];

  /// Retrieves and parses an integer environment variable for [key].
  ///
  /// If [key] is present and successfully parses via [int.tryParse], returns the integer.
  /// If absent or unparseable, returns [defaultValue] if provided.
  /// If absent or unparseable and [defaultValue] is `null`, throws a [StateError].
  ///
  /// ```dart
  /// final port = BloomEnv.getInt('PORT', defaultValue: 8080);
  /// ```
  static int getInt(String key, {int? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = int.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required integer environment variable "$key".');
  }

  /// Retrieves and parses a double-precision floating-point environment variable for [key].
  ///
  /// If [key] is present and parses via [double.tryParse], returns the double.
  /// If absent or unparseable, returns [defaultValue] if provided.
  /// If absent or unparseable and [defaultValue] is `null`, throws a [StateError].
  ///
  /// ```dart
  /// final rate = BloomEnv.getDouble('RATE_LIMIT', defaultValue: 100.0);
  /// ```
  static double getDouble(String key, {double? defaultValue}) {
    if (_env.containsKey(key)) {
      final parsed = double.tryParse(_env[key]!);
      if (parsed != null) return parsed;
    }
    if (defaultValue != null) return defaultValue;
    throw StateError(
        'BloomEnv: Missing required double environment variable "$key".');
  }

  /// Retrieves and parses a boolean environment variable for [key].
  ///
  /// Case-insensitively interprets `"true"`, `"1"`, `"yes"` as `true`, and `"false"`, `"0"`, `"no"` as `false`.
  /// If absent or invalid, returns [defaultValue] if provided.
  /// If absent or invalid and [defaultValue] is `null`, throws a [StateError].
  ///
  /// ```dart
  /// final isProduction = BloomEnv.getBool('IS_PROD', defaultValue: false);
  /// ```
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

  /// Checks whether [key] exists in the loaded environment map.
  ///
  /// ```dart
  /// if (BloomEnv.contains('AUTH_SECRET')) {
  ///   enableAuth();
  /// }
  /// ```
  static bool contains(String key) => _env.containsKey(key);

  /// Checks whether [key] exists in the loaded environment map.
  ///
  /// Convenient alias for [contains].
  ///
  /// ```dart
  /// if (BloomEnv.has('SENTRY_DSN')) {
  ///   initSentry();
  /// }
  /// ```
  static bool has(String key) => contains(key);

  /// Clears all loaded environment variables from the internal store.
  ///
  /// Typically used during test teardown.
  ///
  /// ```dart
  /// BloomEnv.clear();
  /// ```
  static void clear() => _env.clear();

  /// The prefix designating environment variables that are safe for client-side web exposure.
  ///
  /// Variables starting with `BLOOM_PUBLIC_` are considered public and safe to embed into
  /// browser JavaScript / WebAssembly bundles. All variables lacking this prefix are
  /// strictly server-only secrets (e.g. database credentials, API secrets, private keys)
  /// and will be rejected by the Bloom build system if targeted for client compilation.
  static const String publicPrefix = 'BLOOM_PUBLIC_';

  /// Checks whether [key] is designated as client-public.
  ///
  /// The check is an exact prefix match: [key] must begin with [publicPrefix] (`'BLOOM_PUBLIC_'`).
  /// Variables that merely contain this substring elsewhere in their name are not public.
  ///
  /// ```dart
  /// BloomEnv.isPublic('BLOOM_PUBLIC_API_URL'); // true
  /// BloomEnv.isPublic('DATABASE_PASSWORD');    // false
  /// BloomEnv.isPublic('NOT_BLOOM_PUBLIC_KEY'); // false
  /// ```
  static bool isPublic(String key) => key.startsWith(publicPrefix);

  /// Returns an unmodifiable snapshot map of only the client-public environment variables.
  ///
  /// Filters the loaded environment map to include only keys starting with [publicPrefix].
  /// Non-public variables are omitted to ensure server secrets are never bundled into
  /// browser client artifacts.
  ///
  /// ```dart
  /// final publicConfig = BloomEnv.publicVariables;
  /// print('Public vars: ${publicConfig.keys}');
  /// ```
  static Map<String, String> get publicVariables {
    final filtered = <String, String>{};
    for (final entry in _env.entries) {
      if (isPublic(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return UnmodifiableMapView(filtered);
  }

  /// Returns an unmodifiable snapshot map of all currently loaded environment variables.
  ///
  /// ```dart
  /// final map = BloomEnv.all;
  /// print('Loaded env vars: ${map.keys}');
  /// ```
  static Map<String, String> get all => UnmodifiableMapView(_env);
}
