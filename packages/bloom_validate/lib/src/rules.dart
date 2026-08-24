// lib/src/rules.dart
import 'errors.dart';
import 'schema.dart';

/// Mixin providing advanced HTTP body and DTO validation rules.
///
/// Implements declarative extraction and validation helpers for strings, numbers,
/// enums, nested schemas, and lists from raw JSON payloads.
///
/// Classes using this mixin must implement [data], [validationErrors], and [fail],
/// as well as the core primitives [requireString], [optionalString], [requireInt],
/// and [optionalInt].
///
/// Example:
/// ```dart
/// class MySchema extends BloomRequestSchema {
///   MySchema(super.data);
///
///   late final String email = requireEmail('email');
///   late final int age = requireIntRange('age', min: 18, max: 120);
///   late final Role role = requireEnum('role', Role.values);
///
///   @override
///   void validate() {
///     email;
///     age;
///     role;
///   }
/// }
/// ```
mixin BloomValidationRules {
  /// The underlying map of raw request data.
  Map<String, dynamic> get data;

  /// List of accumulated validation errors collected during schema evaluation.
  List<String> get validationErrors;

  /// Records a validation [error] message and immediately throws a [BloomValidationException].
  ///
  /// Example:
  /// ```dart
  /// if (password != confirmPassword) {
  ///   fail('Passwords do not match.');
  /// }
  /// ```
  Never fail(String error);

  /// Requires a non-empty string field [key].
  ///
  /// When [trim] is `true` (default), leading and trailing whitespace is stripped before checking.
  /// An optional [description] provides additional human-readable context in failure messages.
  ///
  /// Throws a [BloomValidationException] if the field is missing, not a string, or empty.
  ///
  /// Example:
  /// ```dart
  /// late final String username = requireString('username', description: 'User account name');
  /// ```
  String requireString(String key, {String? description, bool trim = true});

  /// Reads an optional string field [key] with fallback to [defaultValue].
  ///
  /// When [trim] is `true` (default), whitespace is trimmed. If the field is missing
  /// or empty, returns [defaultValue] (which defaults to `null`).
  ///
  /// Throws a [BloomValidationException] if the field is present but not a string.
  ///
  /// Example:
  /// ```dart
  /// late final String? bio = optionalString('bio', description: 'User biography');
  /// ```
  String? optionalString(String key, {String? defaultValue, String? description, bool trim = true});

  /// Requires a valid integer field [key].
  ///
  /// Accepts `int`, `num`, or parseable integer string representations.
  /// An optional [description] provides additional human-readable context in failure messages.
  ///
  /// Throws a [BloomValidationException] if the field is missing, unparseable, or invalid.
  ///
  /// Example:
  /// ```dart
  /// late final int count = requireInt('count', description: 'Item quantity');
  /// ```
  int requireInt(String key, {String? description});

  /// Reads an optional integer field [key] with fallback to [defaultValue].
  ///
  /// Accepts `int`, `num`, or parseable numeric strings. If missing or empty string,
  /// returns [defaultValue] (which defaults to `null`).
  ///
  /// Throws a [BloomValidationException] if the field is present but not parseable as an integer.
  ///
  /// Example:
  /// ```dart
  /// late final int limit = optionalInt('limit', defaultValue: 20) ?? 20;
  /// ```
  int? optionalInt(String key, {int? defaultValue, String? description});

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
  );

  /// Requires a valid email address string for field [key].
  ///
  /// Validates the string format using standard RFC email syntax pattern matching.
  /// An optional [description] provides additional human-readable context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, empty, or not matching valid email syntax.
  ///
  /// Example:
  /// ```dart
  /// late final String email = requireEmail('email', description: 'Primary contact email');
  /// ```
  String requireEmail(String key, {String? description}) {
    final str = requireString(key, description: description);
    if (!_emailRegExp.hasMatch(str)) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" is not a valid email address: "$str"$desc.');
    }
    return str;
  }

  /// Reads an optional email address string for field [key] with fallback to [defaultValue].
  ///
  /// Validates email syntax if present. If missing or empty, returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but not matching valid email syntax.
  ///
  /// Example:
  /// ```dart
  /// late final String? recoveryEmail = optionalEmail('recoveryEmail');
  /// ```
  String? optionalEmail(String key, {String? defaultValue, String? description}) {
    final str = optionalString(key, defaultValue: defaultValue, description: description);
    if (str == null || str.isEmpty) return defaultValue;
    if (!_emailRegExp.hasMatch(str)) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" is not a valid email address: "$str"$desc.');
    }
    return str;
  }

  /// Requires a string field [key] satisfying optional [min] and [max] length constraints.
  ///
  /// When [trim] is `true` (default), whitespace is trimmed before evaluating character length.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, not a string, or length is outside specified bounds.
  ///
  /// Example:
  /// ```dart
  /// late final String password = requireStringLength('password', min: 8, max: 128);
  /// ```
  String requireStringLength(
    String key, {
    int? min,
    int? max,
    String? description,
    bool trim = true,
  }) {
    final str = requireString(key, description: description, trim: trim);
    final desc = description != null ? ' ($description)' : '';
    if (min != null && str.length < min) {
      fail('Field "$key" must be at least $min characters long (length: ${str.length})$desc.');
    }
    if (max != null && str.length > max) {
      fail('Field "$key" must be at most $max characters long (length: ${str.length})$desc.');
    }
    return str;
  }

  /// Reads an optional string field [key] with optional [min] and [max] length constraints and [defaultValue].
  ///
  /// When [trim] is `true` (default), whitespace is trimmed. If absent or null, returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present and length is outside specified bounds.
  ///
  /// Example:
  /// ```dart
  /// late final String? nickname = optionalStringLength('nickname', min: 2, max: 30);
  /// ```
  String? optionalStringLength(
    String key, {
    int? min,
    int? max,
    String? defaultValue,
    String? description,
    bool trim = true,
  }) {
    final str = optionalString(key, defaultValue: defaultValue, description: description, trim: trim);
    if (str == null) return defaultValue;
    final desc = description != null ? ' ($description)' : '';
    if (min != null && str.length < min) {
      fail('Field "$key" must be at least $min characters long (length: ${str.length})$desc.');
    }
    if (max != null && str.length > max) {
      fail('Field "$key" must be at most $max characters long (length: ${str.length})$desc.');
    }
    return str;
  }

  /// Requires an integer value for field [key] within an optional [min] and [max] range.
  ///
  /// Both [min] and [max] bounds are inclusive.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, unparseable as an integer, or out of range.
  ///
  /// Example:
  /// ```dart
  /// late final int age = requireIntRange('age', min: 18, max: 120, description: 'User age in years');
  /// ```
  int requireIntRange(
    String key, {
    int? min,
    int? max,
    String? description,
  }) {
    final val = requireInt(key, description: description);
    final desc = description != null ? ' ($description)' : '';
    if (min != null && val < min) {
      fail('Field "$key" must be at least $min (got $val)$desc.');
    }
    if (max != null && val > max) {
      fail('Field "$key" must be at most $max (got $val)$desc.');
    }
    return val;
  }

  /// Reads an optional integer value for field [key] within an optional [min] and [max] range.
  ///
  /// Both [min] and [max] bounds are inclusive. If absent or null, returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present and unparseable or out of range.
  ///
  /// Example:
  /// ```dart
  /// late final int? priority = optionalIntRange('priority', min: 1, max: 5, defaultValue: 3);
  /// ```
  int? optionalIntRange(
    String key, {
    int? min,
    int? max,
    int? defaultValue,
    String? description,
  }) {
    final val = optionalInt(key, defaultValue: defaultValue, description: description);
    if (val == null) return defaultValue;
    final desc = description != null ? ' ($description)' : '';
    if (min != null && val < min) {
      fail('Field "$key" must be at least $min (got $val)$desc.');
    }
    if (max != null && val > max) {
      fail('Field "$key" must be at most $max (got $val)$desc.');
    }
    return val;
  }

  /// Requires a value matching one of [allowed] enum/constant options for field [key].
  ///
  /// Supports standard Dart enums (matched by enum name or exact instance) and plain values.
  /// An optional [parser] function can convert raw input into [T] before matching.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing or not in [allowed].
  ///
  /// Example:
  /// ```dart
  /// enum Role { admin, member, viewer }
  ///
  /// late final Role role = requireEnum('role', Role.values);
  /// ```
  T requireEnum<T>(
    String key,
    List<T> allowed, {
    String? description,
    T Function(dynamic raw)? parser,
  }) {
    final raw = data[key];
    final desc = description != null ? ' ($description)' : '';
    if (raw == null) {
      fail('Missing required enum field "$key"$desc.');
    }

    if (parser != null) {
      try {
        final parsed = parser(raw);
        if (allowed.contains(parsed)) return parsed;
      } catch (_) {}
    } else {
      for (final item in allowed) {
        if (item == raw) return item;
        if (item is Enum && item.name == raw.toString().trim()) return item;
        if (item.toString() == raw.toString().trim()) return item;
      }
    }

    final allowedLabels = allowed.map((e) => e is Enum ? e.name : e.toString()).join(', ');
    fail('Field "$key" must be one of [$allowedLabels] (got "$raw")$desc.');
  }

  /// Reads an optional value matching one of [allowed] enum/constant options for field [key].
  ///
  /// Supports standard Dart enums and plain values. If missing or empty, returns [defaultValue].
  /// An optional [parser] function can convert raw input into [T].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but not in [allowed].
  ///
  /// Example:
  /// ```dart
  /// late final Role? role = optionalEnum('role', Role.values, defaultValue: Role.member);
  /// ```
  T? optionalEnum<T>(
    String key,
    List<T> allowed, {
    T? defaultValue,
    String? description,
    T Function(dynamic raw)? parser,
  }) {
    final raw = data[key];
    if (raw == null) return defaultValue;
    if (raw is String && raw.trim().isEmpty) return defaultValue;

    if (parser != null) {
      try {
        final parsed = parser(raw);
        if (allowed.contains(parsed)) return parsed;
      } catch (_) {}
    } else {
      for (final item in allowed) {
        if (item == raw) return item;
        if (item is Enum && item.name == raw.toString().trim()) return item;
        if (item.toString() == raw.toString().trim()) return item;
      }
    }

    final desc = description != null ? ' ($description)' : '';
    final allowedLabels = allowed.map((e) => e is Enum ? e.name : e.toString()).join(', ');
    fail('Field "$key" must be one of [$allowedLabels] (got "$raw")$desc.');
  }

  /// Requires a nested JSON object at field [key] and instantiates a nested schema/model using [schema].
  ///
  /// If the returned object is a [BloomRequestSchema], automatically triggers its `validate()` method.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, not a map, or nested validation fails.
  ///
  /// Example:
  /// ```dart
  /// late final AddressSchema address = requireNested('address', AddressSchema.new);
  /// ```
  T requireNested<T>(
    String key,
    T Function(Map<String, dynamic> json) schema, {
    String? description,
  }) {
    final raw = data[key];
    final desc = description != null ? ' ($description)' : '';
    if (raw == null) {
      fail('Missing required nested object "$key"$desc.');
    }
    if (raw is! Map) {
      fail('Field "$key" must be a JSON object: "$raw"$desc.');
    }
    final map = raw is Map<String, dynamic>
        ? raw
        : raw.map((k, v) => MapEntry(k.toString(), v));
    try {
      final result = schema(map);
      if (result is BloomRequestSchema) {
        result.validate();
      }
      return result;
    } on BloomValidationException {
      rethrow;
    } catch (e) {
      fail('Invalid nested object "$key": $e$desc.');
    }
  }

  /// Reads an optional nested JSON object at field [key] and instantiates it using [schema].
  ///
  /// If the returned object is a [BloomRequestSchema], automatically triggers its `validate()` method.
  /// If absent or null, returns [defaultValue].
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present but not a map or nested validation fails.
  ///
  /// Example:
  /// ```dart
  /// late final MetadataSchema? metadata = optionalNested('metadata', MetadataSchema.new);
  /// ```
  T? optionalNested<T>(
    String key,
    T Function(Map<String, dynamic> json) schema, {
    T? defaultValue,
    String? description,
  }) {
    final raw = data[key];
    if (raw == null) return defaultValue;
    if (raw is! Map) {
      final desc = description != null ? ' ($description)' : '';
      fail('Field "$key" must be a JSON object: "$raw"$desc.');
    }
    final map = raw is Map<String, dynamic>
        ? raw
        : raw.map((k, v) => MapEntry(k.toString(), v));
    try {
      final result = schema(map);
      if (result is BloomRequestSchema) {
        result.validate();
      }
      return result;
    } on BloomValidationException {
      rethrow;
    } catch (e) {
      final desc = description != null ? ' ($description)' : '';
      fail('Invalid nested object "$key": $e$desc.');
    }
  }

  /// Requires a list of JSON objects at field [key] parsed with [itemSchema].
  ///
  /// Validates optional [minLength] and [maxLength] item count constraints.
  /// If elements are [BloomRequestSchema] instances, executes their validation automatically.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, not a list, length out of bounds,
  /// items are not JSON maps, or item validation fails.
  ///
  /// Example:
  /// ```dart
  /// late final List<LineItemSchema> items = requireList(
  ///   'items',
  ///   LineItemSchema.new,
  ///   minLength: 1,
  ///   description: 'Order line items',
  /// );
  /// ```
  List<T> requireList<T>(
    String key,
    T Function(Map<String, dynamic> item) itemSchema, {
    int? minLength,
    int? maxLength,
    String? description,
  }) {
    final raw = data[key];
    final desc = description != null ? ' ($description)' : '';
    if (raw == null) {
      fail('Missing required list "$key"$desc.');
    }
    if (raw is! List) {
      fail('Field "$key" must be a list: "$raw"$desc.');
    }
    if (minLength != null && raw.length < minLength) {
      fail('List "$key" must contain at least $minLength items (got ${raw.length})$desc.');
    }
    if (maxLength != null && raw.length > maxLength) {
      fail('List "$key" must contain at most $maxLength items (got ${raw.length})$desc.');
    }

    final results = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        fail('Item at index $i in list "$key" must be an object: "$item"$desc.');
      }
      final map = item is Map<String, dynamic>
          ? item
          : item.map((k, v) => MapEntry(k.toString(), v));
      try {
        final parsed = itemSchema(map);
        if (parsed is BloomRequestSchema) {
          parsed.validate();
        }
        results.add(parsed);
      } on BloomValidationException {
        rethrow;
      } catch (e) {
        fail('Invalid item at index $i in list "$key": $e$desc.');
      }
    }
    return results;
  }

  /// Reads an optional list of JSON objects at field [key] parsed with [itemSchema].
  ///
  /// Validates optional [minLength] and [maxLength] constraints with fallback to [defaultValue].
  /// If elements are [BloomRequestSchema] instances, executes their validation automatically.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present and invalid.
  ///
  /// Example:
  /// ```dart
  /// late final List<AttachmentSchema>? attachments = optionalList(
  ///   'attachments',
  ///   AttachmentSchema.new,
  ///   maxLength: 10,
  /// );
  /// ```
  List<T>? optionalList<T>(
    String key,
    T Function(Map<String, dynamic> item) itemSchema, {
    List<T>? defaultValue,
    int? minLength,
    int? maxLength,
    String? description,
  }) {
    final raw = data[key];
    if (raw == null) return defaultValue;
    final desc = description != null ? ' ($description)' : '';
    if (raw is! List) {
      fail('Field "$key" must be a list: "$raw"$desc.');
    }
    if (minLength != null && raw.length < minLength) {
      fail('List "$key" must contain at least $minLength items (got ${raw.length})$desc.');
    }
    if (maxLength != null && raw.length > maxLength) {
      fail('List "$key" must contain at most $maxLength items (got ${raw.length})$desc.');
    }

    final results = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        fail('Item at index $i in list "$key" must be an object: "$item"$desc.');
      }
      final map = item is Map<String, dynamic>
          ? item
          : item.map((k, v) => MapEntry(k.toString(), v));
      try {
        final parsed = itemSchema(map);
        if (parsed is BloomRequestSchema) {
          parsed.validate();
        }
        results.add(parsed);
      } on BloomValidationException {
        rethrow;
      } catch (e) {
        fail('Invalid item at index $i in list "$key": $e$desc.');
      }
    }
    return results;
  }

  /// Requires a list of primitive items of type [T] (e.g. `String`, `int`, `double`, `bool`) at field [key].
  ///
  /// Validates optional [minLength] and [maxLength] bounds.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if missing, not a list, length is out of bounds, or items are not [T].
  ///
  /// Example:
  /// ```dart
  /// late final List<String> tags = requirePrimitiveList<String>('tags', minLength: 1, maxLength: 20);
  /// ```
  List<T> requirePrimitiveList<T>(
    String key, {
    int? minLength,
    int? maxLength,
    String? description,
  }) {
    final raw = data[key];
    final desc = description != null ? ' ($description)' : '';
    if (raw == null) {
      fail('Missing required list "$key"$desc.');
    }
    if (raw is! List) {
      fail('Field "$key" must be a list: "$raw"$desc.');
    }
    if (minLength != null && raw.length < minLength) {
      fail('List "$key" must contain at least $minLength items (got ${raw.length})$desc.');
    }
    if (maxLength != null && raw.length > maxLength) {
      fail('List "$key" must contain at most $maxLength items (got ${raw.length})$desc.');
    }

    final list = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! T) {
        fail('Item at index $i in list "$key" must be of type $T: "$item"$desc.');
      }
      list.add(item);
    }
    return list;
  }

  /// Reads an optional list of primitive items of type [T] at field [key] with fallback to [defaultValue].
  ///
  /// Validates optional [minLength] and [maxLength] bounds when present.
  /// An optional [description] provides additional context in failure messages.
  ///
  /// Throws a [BloomValidationException] if present and not a list, length is out of bounds, or items are not [T].
  ///
  /// Example:
  /// ```dart
  /// late final List<int>? ids = optionalPrimitiveList<int>('ids', maxLength: 100);
  /// ```
  List<T>? optionalPrimitiveList<T>(
    String key, {
    List<T>? defaultValue,
    int? minLength,
    int? maxLength,
    String? description,
  }) {
    final raw = data[key];
    if (raw == null) return defaultValue;
    final desc = description != null ? ' ($description)' : '';
    if (raw is! List) {
      fail('Field "$key" must be a list: "$raw"$desc.');
    }
    if (minLength != null && raw.length < minLength) {
      fail('List "$key" must contain at least $minLength items (got ${raw.length})$desc.');
    }
    if (maxLength != null && raw.length > maxLength) {
      fail('List "$key" must contain at most $maxLength items (got ${raw.length})$desc.');
    }

    final list = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! T) {
        fail('Item at index $i in list "$key" must be of type $T: "$item"$desc.');
      }
      list.add(item);
    }
    return list;
  }
}

