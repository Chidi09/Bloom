// lib/src/rules.dart
import 'errors.dart';
import 'schema.dart';

/// Mixin providing advanced HTTP body and DTO validation rules.
mixin BloomValidationRules {
  /// The underlying map of raw request data.
  Map<String, dynamic> get data;

  /// List of accumulated validation errors.
  List<String> get validationErrors;

  /// Records a validation [error] message and throws a [BloomValidationException].
  Never fail(String error);

  /// Requires a non-empty string field [key].
  String requireString(String key, {String? description, bool trim = true});

  /// Reads an optional string field [key] with fallback to [defaultValue].
  String? optionalString(String key, {String? defaultValue, String? description, bool trim = true});

  /// Requires a valid integer field [key].
  int requireInt(String key, {String? description});

  /// Reads an optional integer field [key] with fallback to [defaultValue].
  int? optionalInt(String key, {int? defaultValue, String? description});

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
  );

  /// Requires a valid email address string for field [key].
  ///
  /// Throws [BloomValidationException] if missing or not matching valid email syntax.
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
  /// Throws [BloomValidationException] if present but not matching email syntax.
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
  /// When [trim] is true (default), whitespace is trimmed before evaluating length.
  /// Throws [BloomValidationException] if missing or length is outside specified bounds.
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
  /// When [trim] is true (default), whitespace is trimmed.
  /// Throws [BloomValidationException] if present and length is outside specified bounds.
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
  /// Throws [BloomValidationException] if missing, unparseable, or out of range.
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
  /// Throws [BloomValidationException] if present and out of range.
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
  /// An optional [parser] function can convert raw input into [T].
  /// Throws [BloomValidationException] if missing or not in [allowed].
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
  /// An optional [parser] function can convert raw input into [T].
  /// Throws [BloomValidationException] if present but not in [allowed].
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
  /// If the returned object is a [BloomRequestSchema], triggers [BloomRequestSchema.validate].
  /// Throws [BloomValidationException] if missing, not a map, or nested validation fails.
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
  /// If the returned object is a [BloomRequestSchema], triggers [BloomRequestSchema.validate].
  /// Throws [BloomValidationException] if present but not a map or nested validation fails.
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
  /// Validates optional [minLength] and [maxLength] constraints. If elements are [BloomRequestSchema],
  /// executes their validation.
  /// Throws [BloomValidationException] if missing, not a list, length out of bounds, or item validation fails.
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
  /// Throws [BloomValidationException] if present and invalid.
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
  /// Throws [BloomValidationException] if missing, not a list, length is out of bounds, or items are not [T].
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
  /// Throws [BloomValidationException] if present and invalid.
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

