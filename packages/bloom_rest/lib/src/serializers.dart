// lib/src/serializers.dart
import 'dart:convert';
import 'package:bloom_db/bloom_db.dart';

/// Accumulates field-level and non-field validation errors.
///
/// Mirrors `djangors_rest::ValidationErrors`.
class BloomValidationErrors {
  final Map<String, List<String>> _errors = {};

  BloomValidationErrors();

  /// Adds an error message for [field].
  void add(String field, String message) {
    _errors.putIfAbsent(field, () => []).add(message);
  }

  /// Merges errors from another [BloomValidationErrors] instance.
  void merge(BloomValidationErrors other) {
    for (final entry in other._errors.entries) {
      _errors.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
  }

  /// Whether any errors have been recorded.
  bool get isEmpty => _errors.isEmpty;

  /// Whether at least one error has been recorded.
  bool get isNotEmpty => _errors.isNotEmpty;

  /// Returns the underlying error map.
  Map<String, List<String>> toMap() => Map.unmodifiable(_errors);

  /// Returns a simplified map where single errors are flattened to strings.
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

  const BloomFieldSet({
    this.only = const [],
    this.exclude = const [],
    this.readOnly = const [],
    this.writeOnly = const [],
  });

  /// An unrestricted field set: every model field, both directions.
  factory BloomFieldSet.all() => const BloomFieldSet();

  /// Restrict to exactly these fields.
  factory BloomFieldSet.onlyFields(List<String> fields) =>
      BloomFieldSet(only: List.unmodifiable(fields));

  /// Exclude these fields entirely.
  BloomFieldSet excluding(List<String> fields) => BloomFieldSet(
        only: only,
        exclude: [...exclude, ...fields],
        readOnly: readOnly,
        writeOnly: writeOnly,
      );

  /// Mark these fields read-only: emitted, never accepted on write.
  BloomFieldSet withReadOnly(List<String> fields) => BloomFieldSet(
        only: only,
        exclude: exclude,
        readOnly: [...readOnly, ...fields],
        writeOnly: writeOnly,
      );

  /// Mark these fields write-only: accepted on write, never emitted.
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

  /// Whether the field appears in serialized output.
  bool isReadable(String field) {
    return _inScope(field) && !writeOnly.contains(field);
  }

  /// Whether the field is accepted from client input.
  bool isWritable(String field) {
    return _inScope(field) && !readOnly.contains(field);
  }
}

/// Validator callback on field values.
typedef BloomValidator = void Function(
  Map<String, dynamic> values,
  BloomValidationErrors errors,
);

/// Converts between a model [T] and its wire representation, with validation.
///
/// Mirrors `djangors_rest::Serializer<M>`.
abstract class BloomSerializer<T extends Model> {
  /// Render a model instance for the response body.
  Map<String, dynamic> toRepresentation(T instance);

  /// Parse and validate a request body into column values ready for `insertRaw` / `update`.
  ///
  /// When [partial] is true (PATCH), omitted fields are ignored.
  /// When [partial] is false (POST / PUT), missing required fields are flagged as errors.
  (Map<String, dynamic>?, BloomValidationErrors?) toInternalValue(
    dynamic data, {
    bool partial = false,
  });

  /// Object-level rules run after fields parse successfully.
  void validate(Map<String, dynamic> values, BloomValidationErrors errors) {}

  /// Render an instance with pre-fetched related objects embedded in place of raw FK ids.
  Map<String, dynamic> toRepresentationNested(
    T instance,
    Map<String, dynamic> related,
  ) {
    final base = toRepresentation(instance);
    final map = Map<String, dynamic>.from(base);
    for (final entry in related.entries) {
      if (map.containsKey(entry.key)) {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }

  /// Render a collection of model instances.
  List<Map<String, dynamic>> toRepresentationMany(List<T> instances) {
    return instances.map(toRepresentation).toList();
  }

  /// Parse request body and apply object-level [validate].
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

/// Serializes any [Model]'s `fieldValues()` into a Map.
Map<String, dynamic> serializeModel(Model instance) {
  final map = <String, dynamic>{};
  for (final (name, value) in instance.fieldValues()) {
    map[name] = bloomValueToJson(value);
  }
  return map;
}

/// The default [BloomSerializer]: derives its behaviour from [ModelMeta],
/// narrowed by a [BloomFieldSet].
///
/// Mirrors `djangors_rest::ModelSerializer<M>`.
class BloomModelSerializer<T extends Model> extends BloomSerializer<T> {
  final ModelMeta meta;
  final BloomFieldSet fields;
  final List<BloomValidator> _validators = [];

  BloomModelSerializer({
    required this.meta,
    BloomFieldSet? fields,
  }) : fields = fields ?? BloomFieldSet.all();

  /// Attach an object-level validator rule.
  BloomModelSerializer<T> withValidator(BloomValidator validator) {
    _validators.add(validator);
    return this;
  }

  @override
  Map<String, dynamic> toRepresentation(T instance) {
    final full = serializeModel(instance);
    final filtered = <String, dynamic>{};
    for (final entry in full.entries) {
      if (fields.isReadable(entry.key)) {
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
      if (knownField && !fields.isWritable(key)) {
        errors.add(key, 'field is read-only');
      }
    }

    // 2. Check required fields for non-partial writes (POST / PUT)
    if (!partial) {
      for (final field in meta.fields) {
        if (field.auto ||
            field.primaryKey ||
            field.nullable ||
            !fields.isWritable(field.name)) {
          continue;
        }
        if (!jsonMap.containsKey(field.name) || jsonMap[field.name] == null) {
          errors.add(field.name, 'this field is required');
        }
      }

      for (final relation in meta.relations) {
        if (!fields.isWritable(relation.fieldName)) {
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
        } else if (rawVal is num) {
          values[field.name] = rawVal != 0;
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
          values[field.name] = rawVal;
        } else if (rawVal is DateTime) {
          values[field.name] =
              "${rawVal.year.toString().padLeft(4, '0')}-${rawVal.month.toString().padLeft(2, '0')}-${rawVal.day.toString().padLeft(2, '0')}";
        } else {
          values[field.name] = rawVal.toString();
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
        final id = int.tryParse(rawVal);
        if (id != null) {
          values[rel.fieldName] = id;
        } else {
          errors.add(
              rel.fieldName, "Field '${rel.fieldName}' must be a valid integer ID.");
        }
      } else {
        errors.add(
            rel.fieldName, "Field '${rel.fieldName}' must be a valid integer ID.");
      }
    }

    if (errors.isNotEmpty) {
      return (null, errors);
    }

    // Keep only writable fields
    values.removeWhere((k, _) => !fields.isWritable(k));

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
/// Mirrors `djangors_rest::NestedSerializer<M, R>`.
class BloomNestedSerializer<T extends Model, R extends Model>
    extends BloomSerializer<T> {
  final BloomSerializer<T> base;
  final String relation;
  final BloomSerializer<R> inner;

  BloomNestedSerializer({
    required this.base,
    required this.relation,
    required this.inner,
  });

  /// Renders [instance], embedding [related] at the configured relation field.
  Map<String, dynamic> render(T instance, R? related) {
    if (related == null) {
      return base.toRepresentation(instance);
    }
    final relatedMap = <String, dynamic>{
      relation: inner.toRepresentation(related),
    };
    return base.toRepresentationNested(instance, relatedMap);
  }

  /// Renders a collection of (instance, related) pairs.
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
