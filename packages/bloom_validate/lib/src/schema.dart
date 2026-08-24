// lib/src/schema.dart
import 'package:bloom_server/bloom_server.dart';
import 'errors.dart';
import 'rules.dart';

/// Abstract base class for declarative, strictly typed and validated HTTP request body schemas.
///
/// Provides zero-codegen validation for request bodies, query params, and JSON payloads.
/// Subclasses declare `late final` fields initialized using extraction rules from
/// [BloomValidationRules] and override [validate] to evaluate those fields.
///
/// Example:
/// ```dart
/// class CreatePostSchema extends BloomRequestSchema {
///   CreatePostSchema(super.data);
///   CreatePostSchema.fromRequest(super.request) : super.fromRequest();
///
///   late final String title = requireStringLength('title', min: 3, max: 100);
///   late final String content = requireString('content');
///   late final bool isPublished = optionalBool('isPublished', defaultValue: false);
///
///   @override
///   void validate() {
///     title;
///     content;
///     isPublished;
///   }
/// }
/// ```
abstract class BloomRequestSchema with BloomValidationRules {
  /// The underlying map of raw request data.
  @override
  final Map<String, dynamic> data;

  final List<String> _validationErrors = [];

  /// Creates a schema instance wrapping an in-memory [data] map.
  ///
  /// Example:
  /// ```dart
  /// final schema = CreatePostSchema({'title': 'Hello World', 'content': 'First post'});
  /// ```
  BloomRequestSchema(this.data);

  /// Creates a schema instance by extracting the JSON body from a [BloomRequest].
  ///
  /// If the request body is `null` or not a JSON map, initializes with an empty map.
  ///
  /// Example:
  /// ```dart
  /// final schema = CreatePostSchema.fromRequest(request);
  /// ```
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

  /// Evaluates and validates schema fields.
  ///
  /// Subclasses override this method to access `late` fields, triggering their validation rules.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void validate() {
  ///   title;
  ///   content;
  /// }
  /// ```
  void validate() {}

  /// Records a validation [error] and throws a [BloomValidationException] immediately.
  ///
  /// Example:
  /// ```dart
  /// if (endDate.isBefore(startDate)) {
  ///   fail('endDate must be after startDate');
  /// }
  /// ```
  @override
  Never fail(String error) {
    _validationErrors.add(error);
    throw BloomValidationException(error, errors: List.unmodifiable(_validationErrors));
  }

  /// Evaluates [schema.validate()] and returns the validated [schema], or throws [BloomValidationException].
  ///
  /// Throws [BloomValidationException] when any validation failure occurs.
  ///
  /// Example:
  /// ```dart
  /// final validated = BloomRequestSchema.validateSchema(CreatePostSchema.fromRequest(request));
  /// ```
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
  /// When [trim] is `true` (default), leading and trailing whitespace is stripped before checking.
  /// An optional [description] provides additional human-readable context in failure messages.
  ///
  /// Throws a [BloomValidationException] if the field is missing, not a string, or empty.
  ///
  /// Example:
  /// ```dart
  /// late final String title = requireString('title', description: 'Post title');
  /// ```
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
  /// When [trim] is `true` (default), whitespace is trimmed. If empty or absent, returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but not a string.
  ///
  /// Example:
  /// ```dart
  /// late final String? subtitle = optionalString('subtitle');
  /// ```
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
  /// Accepts `int`, `num` (converted with `.toInt()`), or parseable integer string representations.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, unparseable, or invalid.
  ///
  /// Example:
  /// ```dart
  /// late final int count = requireInt('count', description: 'Item quantity');
  /// ```
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
  /// Accepts `int`, `num`, or parseable numeric strings. If missing or empty string,
  /// returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but unparseable.
  ///
  /// Example:
  /// ```dart
  /// late final int limit = optionalInt('limit', defaultValue: 20) ?? 20;
  /// ```
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
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing or invalid.
  ///
  /// Example:
  /// ```dart
  /// late final bool termsAccepted = requireBool('termsAccepted', description: 'Terms of service agreement');
  /// ```
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
  /// An optional [description] provides additional context in failure messages.
  /// The [defaultValue] defaults to `false`.
  ///
  /// Throws a [BloomValidationException] if present but unparseable as a boolean.
  ///
  /// Example:
  /// ```dart
  /// late final bool subscribeNewsletter = optionalBool('subscribeNewsletter', defaultValue: false);
  /// ```
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
  /// Accepts numeric types (converted via `.toDouble()`) or parseable double strings.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing or unparseable.
  ///
  /// Example:
  /// ```dart
  /// late final double price = requireDouble('price', description: 'Item price in USD');
  /// ```
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
  /// Accepts `num` or parseable double string representations. If absent or empty string,
  /// returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but unparseable as a double.
  ///
  /// Example:
  /// ```dart
  /// late final double? discount = optionalDouble('discount', defaultValue: 0.0);
  /// ```
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
  /// Parses the string representation and validates that it contains a non-empty scheme.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, unparseable, or missing a scheme.
  ///
  /// Example:
  /// ```dart
  /// late final Uri callbackUrl = requireUri('callbackUrl', description: 'OAuth redirect URL');
  /// ```
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
  /// Validates that the URI is absolute (has a scheme) if present. If absent or empty,
  /// returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but unparseable or missing a scheme.
  ///
  /// Example:
  /// ```dart
  /// late final Uri? website = optionalUri('website');
  /// ```
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

