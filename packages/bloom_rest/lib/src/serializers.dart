// lib/src/serializers.dart
import 'dart:convert';
import 'package:bloom_db/bloom_db.dart';

/// Accumulates field-level and non-field validation errors.
///
/// Maps field names to lists of human-readable error messages. Non-field errors
/// (such as invalid root JSON types) are stored under `'non_field_errors'`.
///
/// Example:
/// ```dart
/// final errors = BloomValidationErrors();
/// errors.add('email', 'Invalid email format');
/// errors.add('password', 'Must be at least 8 characters');
/// if (errors.isNotEmpty) {
///   print(errors.toJson());
/// }
/// ```
///
/// Mirrors `djangors_rest::ValidationErrors`.
class BloomValidationErrors {
  final Map<String, List<String>> _errors = {};

  /// Creates an empty [BloomValidationErrors] container.
  BloomValidationErrors();

  /// Adds an error [message] for the specified [field].
  void add(String field, String message) {
    _errors.putIfAbsent(field, () => []).add(message);
  }

  /// Merges errors from [other] into this error container.
  void merge(BloomValidationErrors other) {
    for (final entry in other._errors.entries) {
      _errors.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
  }

  /// Whether any errors have been recorded.
  bool get isEmpty => _errors.isEmpty;

  /// Whether at least one error has been recorded.
  bool get isNotEmpty => _errors.isNotEmpty;

  /// Returns an unmodifiable map of field names to their recorded error message lists.
  Map<String, List<String>> toMap() => Map.unmodifiable(_errors);

  /// Returns a simplified map where single errors are flattened to strings and multiple errors remain lists.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    for (final entry in _errors.entries) {
      if (entry.value.length == 1) {
        map[entry.key] = entry.value.first;
      } else {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }

  @override
  String toString() => 'BloomValidationErrors(${jsonEncode(toJson())})';
}

/// Controls which fields cross the wire, in each direction.
///
/// Configures field visibility for serialization (reads) and deserialization (writes):
/// - [only]: If specified, restricts read/write to this exact allowlist.
/// - [exclude]: Fields completely barred from reads and writes.
/// - [readOnly]: Fields emitted in responses but rejected on writes (e.g. `id`, `created_at`).
/// - [writeOnly]: Fields accepted in requests but omitted from responses (e.g. `password`).
///
/// Example:
/// ```dart
/// final fields = BloomFieldSet.all()
///     .withReadOnly(['id', 'created_at', 'updated_at'])
///     .withWriteOnly(['password_hash'])
///     .excluding(['internal_secret']);
/// ```
///
/// Mirrors `djangors_rest::FieldSet`.
class BloomFieldSet {
  /// When non-empty, only these fields are emitted or accepted.
  /// Empty means "every model field", subject to the exclusions below.
  final List<String> only;

  /// Fields never emitted and never accepted, in either direction.
  final List<String> exclude;

  /// Fields emitted on read but silently/loudly dropped from writes (e.g. `id`, `created_at`).
  final List<String> readOnly;

  /// Fields accepted on write but never emitted (e.g. `password`).
  final List<String> writeOnly;

  /// Creates a [BloomFieldSet] with explicit lists for [only], [exclude], [readOnly], and [writeOnly].
  const BloomFieldSet({
    this.only = const [],
    this.exclude = const [],
    this.readOnly = const [],
    this.writeOnly = const [],
  });

  /// An unrestricted field set: every model field, both directions.
  factory BloomFieldSet.all() => const BloomFieldSet();

  /// Restrict to exactly these [fields].
  factory BloomFieldSet.onlyFields(List<String> fields) =>
      BloomFieldSet(only: List.unmodifiable(fields));

  /// Exclude these [fields] entirely from both reading and writing.
  BloomFieldSet excluding(List<String> fields) => BloomFieldSet(
        only: only,
        exclude: [...exclude, ...fields],
        readOnly: readOnly,
        writeOnly: writeOnly,
      );

  /// Mark these [fields] read-only: emitted on reads, rejected on writes.
  BloomFieldSet withReadOnly(List<String> fields) => BloomFieldSet(
        only: only,
        exclude: exclude,
        readOnly: [...readOnly, ...fields],
        writeOnly: writeOnly,
      );

  /// Mark these [fields] write-only: accepted on writes, never emitted in responses.
  BloomFieldSet withWriteOnly(List<String> fields) => BloomFieldSet(
        only: only,
        exclude: exclude,
        readOnly: readOnly,
        writeOnly: [...writeOnly, ...fields],
      );

  bool _inScope(String field) {
    if (exclude.contains(field)) {
      return false;
    }
    return only.isEmpty || only.contains(field);
  }

  /// Whether [field] appears in serialized output.
  bool isReadable(String field) {
    return _inScope(field) && !writeOnly.contains(field);
  }

  /// Whether [field] is accepted from client input.
  bool isWritable(String field) {
    return _inScope(field) && !readOnly.contains(field);
  }
}

/// Validator callback on parsed field values.
///
/// Receives the coerced column [values] map and an [errors] accumulator.
typedef BloomValidator = void Function(
  Map<String, dynamic> values,
  BloomValidationErrors errors,
);

/// Converts between a model [T] and its wire representation, with validation.
///
/// Defines the serialization protocol:
/// - [toRepresentation]: converts a model instance to a JSON map.
/// - [toInternalValue]: parses and validates request payloads.
/// - [validate]: executes cross-field or object-level validation rules.
///
/// Example:
/// ```dart
/// class CustomArticleSerializer extends BloomSerializer<Article> {
///   @override
///   Map<String, dynamic> toRepresentation(Article instance) => {
///     'id': instance.id,
///     'title': instance.title,
///   };
///
///   @override
///   (Map<String, dynamic>?, BloomValidationErrors?) toInternalValue(
///     dynamic data, {
///     bool partial = false,
///   }) {
///     if (data is! Map) return (null, BloomValidationErrors()..add('non_field_errors', 'Expected map'));
///     return (Map<String, dynamic>.from(data), null);
///   }
/// }
/// ```
///
/// Mirrors `djangors_rest::Serializer<M>`.
abstract class BloomSerializer<T extends Model> {
  /// Render a model [instance] for the response body.
  Map<String, dynamic> toRepresentation(T instance);

  /// Parse and validate a request body [data] into column values ready for `insertRaw` / `update`.
  ///
  /// When [partial] is `true` (PATCH), omitted fields are ignored.
  /// When [partial] is `false` (POST / PUT), missing required fields are flagged as errors.
  (Map<String, dynamic>?, BloomValidationErrors?) toInternalValue(
    dynamic data, {
    bool partial = false,
  });

  /// Object-level rules run after fields parse successfully.
  ///
  /// Adds errors to [errors] if constraints on [values] are violated.
  void validate(Map<String, dynamic> values, BloomValidationErrors errors) {}

  /// Render an [instance] with pre-fetched [related] objects embedded in place of raw FK ids.
  Map<String, dynamic> toRepresentationNested(
    T instance,
    Map<String, dynamic> related,
  ) {
    final base = toRepresentation(instance);
    final map = Map<String, dynamic>.from(base);
    for (final entry in related.entries) {
      if (!map.containsKey(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'related',
          'Related field does not exist in the serialized representation',
        );
      }
      map[entry.key] = entry.value;
    }
    return map;
  }

  /// Render a collection of model [instances].
  List<Map<String, dynamic>> toRepresentationMany(List<T> instances) {
    return instances.map(toRepresentation).toList();
  }

  /// Parse request body [data] and apply object-level [validate].
  ///
  /// Returns a tuple containing the valid column map, or [BloomValidationErrors] if validation fails.
  (Map<String, dynamic>?, BloomValidationErrors?) parse(
    dynamic data, {
    bool partial = false,
  }) {
    final (values, errors) = toInternalValue(data, partial: partial);
    if (errors != null && errors.isNotEmpty) {
      return (null, errors);
    }
    if (values == null) {
      final err = BloomValidationErrors()
        ..add('non_field_errors', 'Expected JSON object');
      return (null, err);
    }

    final validationErrors = BloomValidationErrors();
    validate(values, validationErrors);
    if (validationErrors.isNotEmpty) {
      return (null, validationErrors);
    }
    return (values, null);
  }
}

/// Converts a single ORM [BloomValue] into a JSON-compatible dynamic value.
///
/// Formats [BloomDateTimeValue] as UTC ISO-8601 strings and unpacks numeric, boolean,
/// string, null, and list variants.
dynamic bloomValueToJson(BloomValue value) {
  return switch (value) {
    BloomI64Value(:final value) => value,
    BloomF64Value(:final value) => value,
    BloomTextValue(:final value) => value,
    BloomBoolValue(:final value) => value,
    BloomDateTimeValue(:final value) => value.toUtc().toIso8601String(),
    BloomNullValue() => null,
    BloomListValue(:final items) => items.map(bloomValueToJson).toList(),
  };
}

/// Serializes any [Model]'s `fieldValues()` into a JSON-ready Map.
Map<String, dynamic> serializeModel(Model instance) {
  final map = <String, dynamic>{};
  for (final (name, value) in instance.fieldValues()) {
    map[name] = bloomValueToJson(value);
  }
  return map;
}

/// Conventionally sensitive field names excluded from model serialization and deserialization by default.
///
/// These fields are barred from both response representation (reads) and client request inputs (writes)
/// unless [BloomModelSerializer.includeSensitiveFields] is explicitly set to `true`.
const Set<String> kDefaultSensitiveFields = {
  'password',
  'password_hash',
  'token',
  'access_token',
  'refresh_token',
  'secret',
  'api_key',
};

/// The default [BloomSerializer]: derives its behaviour from [ModelMeta],
/// narrowed by a [BloomFieldSet].
///
/// Automatically handles type coercion, required-field checks, foreign key parsing,
/// and field set exclusions. Sensitive fields are excluded by default for security.
///
/// Example:
/// ```dart
/// final serializer = BloomModelSerializer<Article>(
///   meta: Article.meta,
///   fields: BloomFieldSet.all().withReadOnly(['id', 'created_at']),
/// ).withValidator((values, errors) {
///   if (values['title'] == 'forbidden') {
///     errors.add('title', 'This title is not allowed');
///   }
/// });
/// ```
///
/// Mirrors `djangors_rest::ModelSerializer<M>`.
class BloomModelSerializer<T extends Model> extends BloomSerializer<T> {
  /// Model metadata describing database columns, types, and relations.
  final ModelMeta meta;

  /// Field set controlling which fields are exposed on read and accepted on write.
  final BloomFieldSet fields;

  /// Whether conventionally sensitive fields ([kDefaultSensitiveFields]) are exposed.
  ///
  /// Defaults to `false` (SECURE BY DEFAULT). When `false`, fields like `password`,
  /// `password_hash`, `token`, `access_token`, `refresh_token`, `secret`, and `api_key`
  /// are neither serialized in response outputs nor accepted in request inputs.
  final bool includeSensitiveFields;

  final List<BloomValidator> _validators = [];

  /// Creates a [BloomModelSerializer] for [meta] with optional [fields] filtering.
  BloomModelSerializer({
    required this.meta,
    BloomFieldSet? fields,
    this.includeSensitiveFields = false,
  }) : fields = fields ?? BloomFieldSet.all();

  /// Whether [fieldName] is readable by this serializer.
  bool isFieldReadable(String fieldName) {
    if (!includeSensitiveFields &&
        kDefaultSensitiveFields.contains(fieldName)) {
      return false;
    }
    return fields.isReadable(fieldName);
  }

  /// Whether [fieldName] is writable by this serializer.
  bool isFieldWritable(String fieldName) {
    if (!includeSensitiveFields &&
        kDefaultSensitiveFields.contains(fieldName)) {
      return false;
    }
    return fields.isWritable(fieldName);
  }

  /// Attaches an object-level [validator] rule executed during [validate].
  BloomModelSerializer<T> withValidator(BloomValidator validator) {
    _validators.add(validator);
    return this;
  }

  @override
  Map<String, dynamic> toRepresentation(T instance) {
    final full = serializeModel(instance);
    final filtered = <String, dynamic>{};
    for (final entry in full.entries) {
      if (isFieldReadable(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  @override
  (Map<String, dynamic>?, BloomValidationErrors?) toInternalValue(
    dynamic data, {
    bool partial = false,
  }) {
    if (data is! Map) {
      final err = BloomValidationErrors()
        ..add('non_field_errors', 'Expected JSON object');
      return (null, err);
    }

    final errors = BloomValidationErrors();
    final jsonMap = Map<String, dynamic>.from(data);

    // 1. Reject writes to read-only or excluded fields loudly
    for (final key in jsonMap.keys) {
      final knownField = meta.findField(key) != null ||
          meta.relations.any((r) => r.fieldName == key);
      if (knownField && !isFieldWritable(key)) {
        errors.add(key, 'field is read-only');
      }
    }

    // 2. Check required fields for non-partial writes (POST / PUT)
    if (!partial) {
      for (final field in meta.fields) {
        if (field.auto ||
            field.primaryKey ||
            field.nullable ||
            !isFieldWritable(field.name)) {
          continue;
        }
        if (!jsonMap.containsKey(field.name) || jsonMap[field.name] == null) {
          errors.add(field.name, 'this field is required');
        }
      }

      for (final relation in meta.relations) {
        if (!isFieldWritable(relation.fieldName)) {
          continue;
        }
        if (!jsonMap.containsKey(relation.fieldName) ||
            jsonMap[relation.fieldName] == null) {
          errors.add(relation.fieldName, 'this field is required');
        }
      }
    }

    // 3. Parse and coerce field values
    final values = <String, dynamic>{};

    for (final field in meta.fields) {
      if (field.auto) continue;
      if (!jsonMap.containsKey(field.name)) {
        if (partial) continue;
        // In full write, if nullable and not supplied, set null
        if (field.nullable) {
          values[field.name] = null;
        }
        continue;
      }

      final rawVal = jsonMap[field.name];
      if (rawVal == null) {
        if (field.nullable) {
          values[field.name] = null;
        } else {
          // Already recorded required error or record now
          if (!errors.toMap().containsKey(field.name)) {
            errors.add(field.name, "Field '${field.name}' is required.");
          }
        }
        continue;
      }

      // Type coercion per FieldKind
      final kind = field.kind;
      if (kind == FieldKind.boolean) {
        if (rawVal is bool) {
          values[field.name] = rawVal;
        } else if (rawVal is String) {
          final s = rawVal.toLowerCase().trim();
          if (s == 'true' || s == '1') {
            values[field.name] = true;
          } else if (s == 'false' || s == '0') {
            values[field.name] = false;
          } else {
            errors.add(
                field.name, "Field '${field.name}' must be a valid boolean.");
          }
        } else {
          errors.add(
              field.name, "Field '${field.name}' must be a valid boolean.");
        }
      } else if (kind == FieldKind.integer || kind == FieldKind.bigInt) {
        if (rawVal is int) {
          values[field.name] = rawVal;
        } else if (rawVal is num) {
          values[field.name] = rawVal.toInt();
        } else if (rawVal is String) {
          final n = int.tryParse(rawVal);
          if (n != null) {
            values[field.name] = n;
          } else {
            errors.add(
                field.name, "Field '${field.name}' must be a valid integer.");
          }
        } else {
          errors.add(
              field.name, "Field '${field.name}' must be a valid integer.");
        }
      } else if (kind == FieldKind.float || kind is DecimalFieldKind) {
        if (rawVal is num) {
          values[field.name] = rawVal.toDouble();
        } else if (rawVal is String) {
          final d = double.tryParse(rawVal);
          if (d != null) {
            values[field.name] = d;
          } else {
            errors.add(
                field.name, "Field '${field.name}' must be a valid float.");
          }
        } else {
          errors.add(
              field.name, "Field '${field.name}' must be a valid float.");
        }
      } else if (kind == FieldKind.dateTime) {
        if (rawVal is DateTime) {
          values[field.name] = rawVal.toUtc();
        } else if (rawVal is String) {
          final dt = DateTime.tryParse(rawVal);
          if (dt != null) {
            values[field.name] = dt.toUtc();
          } else {
            errors.add(field.name,
                "Field '${field.name}' must be in ISO-8601 / YYYY-MM-DD HH:MM:SS format.");
          }
        } else {
          errors.add(field.name,
              "Field '${field.name}' must be in ISO-8601 / YYYY-MM-DD HH:MM:SS format.");
        }
      } else if (kind == FieldKind.date) {
        if (rawVal is String) {
          final parsed = DateTime.tryParse(rawVal);
          final isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawVal);
          if (parsed != null && isoDate) {
            values[field.name] = rawVal;
          } else {
            errors.add(field.name,
                "Field '${field.name}' must be in YYYY-MM-DD format.");
          }
        } else if (rawVal is DateTime) {
          values[field.name] =
              "${rawVal.year.toString().padLeft(4, '0')}-${rawVal.month.toString().padLeft(2, '0')}-${rawVal.day.toString().padLeft(2, '0')}";
        } else {
          errors.add(field.name,
              "Field '${field.name}' must be in YYYY-MM-DD format.");
        }
      } else {
        // String, text, json, email, url, etc.
        if (rawVal is String) {
          values[field.name] = rawVal;
        } else if (kind == FieldKind.json) {
          values[field.name] = rawVal is String ? rawVal : jsonEncode(rawVal);
        } else {
          values[field.name] = rawVal.toString();
        }
      }
    }

    // Parse relations (Foreign keys)
    for (final rel in meta.relations) {
      if (!jsonMap.containsKey(rel.fieldName)) {
        if (partial) continue;
        continue;
      }
      final rawVal = jsonMap[rel.fieldName];
      if (rawVal == null) {
        values[rel.fieldName] = null;
      } else if (rawVal is int) {
        values[rel.fieldName] = rawVal;
      } else if (rawVal is String) {
        final targetMeta = rel.target();
        final isIntPk = targetMeta.primaryKeyField.kind == FieldKind.integer ||
            targetMeta.primaryKeyField.kind == FieldKind.bigInt;
        if (isIntPk) {
          final id = int.tryParse(rawVal);
          if (id != null) {
            values[rel.fieldName] = id;
          } else {
            errors.add(rel.fieldName,
                "Field '${rel.fieldName}' must be a valid integer ID.");
          }
        } else {
          values[rel.fieldName] = rawVal;
        }
      } else {
        values[rel.fieldName] = rawVal;
      }
    }

    if (errors.isNotEmpty) {
      return (null, errors);
    }

    // Keep only writable fields
    values.removeWhere((k, _) => !isFieldWritable(k));

    return (values, null);
  }

  @override
  void validate(Map<String, dynamic> values, BloomValidationErrors errors) {
    for (final v in _validators) {
      v(values, errors);
    }
  }
}

/// Composes two serializers so a relation renders as a nested object instead of
/// a bare foreign-key ID.
///
/// Example:
/// ```dart
/// final serializer = BloomNestedSerializer<Article, Author>(
///   base: BloomModelSerializer<Article>(meta: Article.meta),
///   relation: 'author',
///   inner: BloomModelSerializer<Author>(meta: Author.meta),
/// );
/// ```
///
/// Mirrors `djangors_rest::NestedSerializer<M, R>`.
class BloomNestedSerializer<T extends Model, R extends Model>
    extends BloomSerializer<T> {
  /// Base serializer for the primary model instance.
  final BloomSerializer<T> base;

  /// Target field or relation name where the nested object is rendered.
  final String relation;

  /// Serializer used to serialize the related child model instance.
  final BloomSerializer<R> inner;

  /// Creates a [BloomNestedSerializer] nesting [inner] into [base] at [relation].
  BloomNestedSerializer({
    required this.base,
    required this.relation,
    required this.inner,
  });

  /// Renders [instance], embedding [related] at the configured [relation] field.
  Map<String, dynamic> render(T instance, R? related) {
    if (related == null) {
      return base.toRepresentation(instance);
    }
    final relatedMap = <String, dynamic>{
      relation: inner.toRepresentation(related),
    };
    return base.toRepresentationNested(instance, relatedMap);
  }

  /// Renders a collection of ([T], [R]?) model pairs into JSON maps.
  List<Map<String, dynamic>> renderMany(List<(T, R?)> rows) {
    return rows.map((pair) => render(pair.$1, pair.$2)).toList();
  }

  @override
  Map<String, dynamic> toRepresentation(T instance) {
    return base.toRepresentation(instance);
  }

  @override
  (Map<String, dynamic>?, BloomValidationErrors?) toInternalValue(
    dynamic data, {
    bool partial = false,
  }) {
    return base.toInternalValue(data, partial: partial);
  }

  @override
  void validate(Map<String, dynamic> values, BloomValidationErrors errors) {
    base.validate(values, errors);
  }
}
