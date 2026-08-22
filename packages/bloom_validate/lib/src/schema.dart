// lib/src/schema.dart
import 'package:bloom_server/bloom_server.dart';
import 'errors.dart';
import 'rules.dart';

/// Abstract base class for strictly typed and validated HTTP request body schemas.
///
/// Mirrors the `BloomEnvironmentSchema` declarative validation pattern for request payloads.
abstract class BloomRequestSchema with BloomValidationRules {
  /// The underlying map of raw request data.
  @override
  final Map<String, dynamic> data;

  final List<String> _validationErrors = [];

  /// Creates a schema instance wrapping an in-memory [data] map.
  BloomRequestSchema(this.data);

  /// Creates a schema instance by reading JSON body from a [BloomRequest].
  BloomRequestSchema.fromRequest(BloomRequest request)
      : data = _extractBodyMap(request.bodyJson);

  /// Helper to safely normalize dynamic body payload to `Map<String, dynamic>`.
  static Map<String, dynamic> _extractBodyMap(dynamic body) {
    if (body == null) return const <String, dynamic>{};
    if (body is Map<String, dynamic>) return body;
    if (body is Map) {
      return body.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  /// List of accumulated validation errors encountered during schema evaluation.
  @override
  List<String> get validationErrors => List.unmodifiable(_validationErrors);

  /// Evaluates and validates schema fields. Subclasses override to evaluate `late` fields.
  void validate() {}

  /// Records a validation [error] and throws [BloomValidationException] immediately.
  @override
  Never fail(String error) {
    _validationErrors.add(error);
    throw BloomValidationException(error, errors: List.unmodifiable(_validationErrors));
  }

  /// Evaluates [schema.validate()] and returns the validated schema, or throws [BloomValidationException].
  ///
  /// Throws [BloomValidationException] when any validation error occurs.
  static T validateSchema<T extends BloomRequestSchema>(T schema) {
    schema.validate();
    if (schema.validationErrors.isNotEmpty) {
      throw BloomValidationException(
        'Validation failed: ${schema.validationErrors.join(', ')}',
        errors: schema.validationErrors,
      );
    }
    return schema;
  }

  /// Requires a non-empty string field [key].
  ///
  /// When [trim] is true (default), leading and trailing whitespace is stripped before checking.
  /// Throws [BloomValidationException] if missing, non-string, or empty.
  @override
  String requireString(String key, {String? description, bool trim = true}) {
    final val = data[key];
    if (val == null) {
      final desc = description != null ? ' ($description)' : '';
      fail('Missing required field "$key"$desc.');
    }
    if (val is! String) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" must be a string: "$val"$desc.');
    }
    final str = trim ? val.trim() : val;
    if (str.isEmpty) {
      final desc = description != null ? ' ($description)' : '';
      fail('Missing required field "$key"$desc.');
    }
    return str;
  }

  /// Reads an optional string field [key] with fallback to [defaultValue].
  ///
  /// When [trim] is true (default), whitespace is trimmed. If empty or absent, returns [defaultValue].
  /// Throws [BloomValidationException] if present but not a string.
  @override
  String? optionalString(String key, {String? defaultValue, String? description, bool trim = true}) {
    final val = data[key];
    if (val == null) return defaultValue;
    if (val is! String) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" must be a string: "$val"$desc.');
    }
    final str = trim ? val.trim() : val;
    if (str.isEmpty) return defaultValue;
    return str;
  }

  /// Requires a valid integer field [key].
  ///
  /// Throws [BloomValidationException] if missing, unparseable, or invalid.
  @override
  int requireInt(String key, {String? description}) {
    final val = data[key];
    if (val == null) {
      final desc = description != null ? ' ($description)' : '';
      fail('Missing required integer field "$key"$desc.');
    }
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) {
        final desc = description != null ? ' ($description)' : '';
        fail('Missing required integer field "$key"$desc.');
      }
      final parsed = int.tryParse(trimmed);
      if (parsed == null) {
        final desc = description != null ? ' ($description)' : '';
        fail('Field "$key" is not a valid integer: "$val"$desc.');
      }
      return parsed;
    }
    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid integer: "$val"$desc.');
  }

  /// Reads an optional integer field [key] with fallback to [defaultValue].
  ///
  /// Throws [BloomValidationException] if present but unparseable.
  @override
  int? optionalInt(String key, {int? defaultValue, String? description}) {
    final val = data[key];
    if (val == null) return defaultValue;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return defaultValue;
      final parsed = int.tryParse(trimmed);
      if (parsed == null) {
        final desc = description != null ? ' ($description)' : '';
        fail('Field "$key" is not a valid integer: "$val"$desc.');
      }
      return parsed;
    }
    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid integer: "$val"$desc.');
  }

  /// Requires a valid boolean field [key].
  ///
  /// Accepts boolean literals, integer `1`/`0`, or strings `'true'`/`'false'`, `'yes'`/`'no'`, `'1'`/`'0'`.
  /// Throws [BloomValidationException] if missing or invalid.
  bool requireBool(String key, {String? description}) {
    final val = data[key];
    if (val == null) {
      final desc = description != null ? ' ($description)' : '';
      fail('Missing required boolean field "$key"$desc.');
    }
    if (val is bool) return val;
    if (val is String) {
      final lower = val.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (val == 1) return true;
    if (val == 0) return false;

    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid boolean: "$val"$desc.');
  }

  /// Reads an optional boolean field [key] with fallback to [defaultValue].
  ///
  /// Accepts booleans, integer `1`/`0`, or string representations.
  /// Throws [BloomValidationException] if present but unparseable as a boolean.
  bool optionalBool(String key, {bool defaultValue = false, String? description}) {
    final val = data[key];
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is String) {
      final lower = val.trim().toLowerCase();
      if (lower.isEmpty) return defaultValue;
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (val == 1) return true;
    if (val == 0) return false;

    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid boolean: "$val"$desc.');
  }

  /// Requires a valid double field [key].
  ///
  /// Throws [BloomValidationException] if missing or unparseable.
  double requireDouble(String key, {String? description}) {
    final val = data[key];
    if (val == null) {
      final desc = description != null ? ' ($description)' : '';
      fail('Missing required double field "$key"$desc.');
    }
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) {
        final desc = description != null ? ' ($description)' : '';
        fail('Missing required double field "$key"$desc.');
      }
      final parsed = double.tryParse(trimmed);
      if (parsed == null) {
        final desc = description != null ? ' ($description)' : '';
        fail('Field "$key" is not a valid double: "$val"$desc.');
      }
      return parsed;
    }
    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid double: "$val"$desc.');
  }

  /// Reads an optional double field [key] with fallback to [defaultValue].
  ///
  /// Throws [BloomValidationException] if present but unparseable as a double.
  double? optionalDouble(String key, {double? defaultValue, String? description}) {
    final val = data[key];
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return defaultValue;
      final parsed = double.tryParse(trimmed);
      if (parsed == null) {
        final desc = description != null ? ' ($description)' : '';
        fail('Field "$key" is not a valid double: "$val"$desc.');
      }
      return parsed;
    }
    final desc = description != null ? ' ($description)' : '';
    fail('Field "$key" is not a valid double: "$val"$desc.');
  }

  /// Requires a valid absolute [Uri] field [key].
  ///
  /// Throws [BloomValidationException] if missing, unparseable, or missing a scheme.
  Uri requireUri(String key, {String? description}) {
    final str = requireString(key, description: description);
    final parsed = Uri.tryParse(str);
    if (parsed == null || !parsed.hasScheme) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" is not a valid absolute URI: "$str"$desc.');
    }
    return parsed;
  }

  /// Reads an optional absolute [Uri] field [key] with fallback to [defaultValue].
  ///
  /// Throws [BloomValidationException] if present but unparseable or missing a scheme.
  Uri? optionalUri(String key, {Uri? defaultValue, String? description}) {
    final val = optionalString(key, description: description);
    if (val == null || val.isEmpty) return defaultValue;
    final parsed = Uri.tryParse(val);
    if (parsed == null || !parsed.hasScheme) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" is not a valid absolute URI: "$val"$desc.');
    }
    return parsed;
  }
}

