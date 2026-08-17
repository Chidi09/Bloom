// lib/src/meta.dart

/// Represents the database field type.
///
/// Mirrors `djangors_orm::meta::FieldKind`.
sealed class FieldKind {
  /// Base const constructor for field kinds.
  const FieldKind();

  /// Text field with a maximum length. Django's `CharField`.
  static const char = _SimpleFieldKind('char');

  /// Unbounded text field. Django's `TextField`.
  static const text = _SimpleFieldKind('text');

  /// A path/key stored in a configured file storage backend. Django's `FileField`.
  static const fileField = _SimpleFieldKind('fileField');

  /// Standard 32-bit signed integer. Django's `IntegerField`.
  static const integer = _SimpleFieldKind('integer');

  /// 64-bit signed integer. Django's `BigIntegerField`.
  static const bigInt = _SimpleFieldKind('bigInt');

  /// Floating point number. Django's `FloatField`.
  static const float = _SimpleFieldKind('float');

  /// Boolean field. Django's `BooleanField`.
  static const boolean = _SimpleFieldKind('boolean');

  /// Date field. Django's `DateField`.
  static const date = _SimpleFieldKind('date');

  /// Date and time field. Django's `DateTimeField`.
  static const dateTime = _SimpleFieldKind('dateTime');

  /// Time field. Django's `TimeField`.
  static const time = _SimpleFieldKind('time');

  /// Duration / delta time field. Django's `DurationField`.
  static const duration = _SimpleFieldKind('duration');

  /// Universally unique identifier. Django's `UUIDField`.
  static const uuid = _SimpleFieldKind('uuid');

  /// Email address field. Django's `EmailField`.
  static const email = _SimpleFieldKind('email');

  /// URL field. Django's `URLField`.
  static const url = _SimpleFieldKind('url');

  /// Slug field (for URLs). Django's `SlugField`.
  static const slug = _SimpleFieldKind('slug');

  /// IP address field. Django's `GenericIPAddressField`.
  static const ip = _SimpleFieldKind('ip');

  /// Binary data field. Django's `BinaryField`.
  static const binary = _SimpleFieldKind('binary');

  /// JSON-encoded data field. Django's `JSONField`.
  static const json = _SimpleFieldKind('json');

  /// Fixed-precision decimal number with [precision] and [scale]. Django's `DecimalField`.
  const factory FieldKind.decimal({
    required int precision,
    required int scale,
  }) = DecimalFieldKind;

  /// The string identifier name of this field kind.
  String get name;
}

class _SimpleFieldKind extends FieldKind {
  @override
  final String name;

  const _SimpleFieldKind(this.name);

  @override
  String toString() => 'FieldKind.$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SimpleFieldKind &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Fixed-precision decimal field kind with [precision] and [scale].
class DecimalFieldKind extends FieldKind {
  /// The maximum number of digits allowed in the number.
  final int precision;

  /// The number of decimal places to store with the number.
  final int scale;

  /// Creates a decimal field kind with [precision] total digits and [scale] decimal digits.
  const DecimalFieldKind({required this.precision, required this.scale});


  @override
  String get name => 'decimal';

  @override
  String toString() => 'FieldKind.decimal(precision: $precision, scale: $scale)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecimalFieldKind &&
          runtimeType == other.runtimeType &&
          precision == other.precision &&
          scale == other.scale;

  @override
  int get hashCode => Object.hash(precision, scale);
}

/// Represents the default value of a model field.
///
/// Mirrors `djangors_orm::meta::DefaultValue`.
sealed class DefaultValue {
  /// Base const constructor for default values.
  const DefaultValue();

  /// Integer default value.
  const factory DefaultValue.i64(int value) = _I64DefaultValue;

  /// Floating point default value.
  const factory DefaultValue.f64(double value) = _F64DefaultValue;

  /// Text default value.
  const factory DefaultValue.text(String value) = _TextDefaultValue;

  /// Boolean default value.
  const factory DefaultValue.boolVal(bool value) = _BoolDefaultValue;

  /// No default value.
  const factory DefaultValue.none() = _NoneDefaultValue;

  /// Returns the underlying raw value, or `null` if none.
  dynamic get rawValue;
}

class _I64DefaultValue extends DefaultValue {
  final int value;
  const _I64DefaultValue(this.value);

  @override
  int get rawValue => value;

  @override
  String toString() => 'DefaultValue.i64($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _I64DefaultValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _F64DefaultValue extends DefaultValue {
  final double value;
  const _F64DefaultValue(this.value);

  @override
  double get rawValue => value;

  @override
  String toString() => 'DefaultValue.f64($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _F64DefaultValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _TextDefaultValue extends DefaultValue {
  final String value;
  const _TextDefaultValue(this.value);

  @override
  String get rawValue => value;

  @override
  String toString() => 'DefaultValue.text("$value")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TextDefaultValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _BoolDefaultValue extends DefaultValue {
  final bool value;
  const _BoolDefaultValue(this.value);

  @override
  bool get rawValue => value;

  @override
  String toString() => 'DefaultValue.boolVal($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BoolDefaultValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _NoneDefaultValue extends DefaultValue {
  const _NoneDefaultValue();

  @override
  Null get rawValue => null;

  @override
  String toString() => 'DefaultValue.none()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NoneDefaultValue && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

/// The kind of relation between models.
///
/// Mirrors `djangors_orm::meta::RelationKind`.
enum RelationKind {
  /// Many-to-one relation. Django's `ForeignKey`.
  foreignKey,

  /// One-to-one relation. Django's `OneToOneField`.
  oneToOne,

  /// Many-to-many relation. Django's `ManyToManyField`.
  manyToMany,
}

/// Action to take when a referenced object is deleted.
///
/// Mirrors `djangors_orm::meta::OnDelete`.
enum OnDelete {
  /// Cascade deletes. Django's `CASCADE`.
  cascade,

  /// Prevent deletion of referenced object. Django's `PROTECT`.
  protect,

  /// Set the reference to NULL. Django's `SET_NULL`.
  setNull,

  /// Prevent deletion of referenced object (SQL standard). Django's `RESTRICT`.
  restrict,

  /// Take no action. Django's `DO_NOTHING`.
  doNothing,
}

/// Metadata for a single model field.
///
/// Mirrors `djangors_orm::meta::FieldMeta`.
class FieldMeta {
  /// The name of the field on the Dart class.
  final String name;

  /// The database column name for this field.
  final String columnName;

  /// The database field type.
  final FieldKind kind;

  /// Whether the field is allowed to be NULL. Django's `null` parameter.
  final bool nullable;

  /// Whether this field is the primary key. Django's `primary_key` parameter.
  final bool primaryKey;

  /// Whether the field is auto-incremented or auto-generated. Django's `AutoField`.
  final bool auto;

  /// Whether the field values must be unique across the table. Django's `unique` parameter.
  final bool unique;

  /// Whether a database index should be created for this field. Django's `db_index` parameter.
  final bool dbIndex;

  /// The default value for the field. Django's `default` parameter.
  final DefaultValue defaultVal;

  /// The maximum length in characters (useful for Char fields). Django's `max_length` parameter.
  final int? maxLength;

  /// A human-readable name for the field. Django's `verbose_name` parameter.
  final String? verboseName;

  /// Extra helper text for forms. Django's `help_text` parameter.
  final String? helpText;

  /// Choices for field values, as (db_value, human_readable_label) pairs. Django's `choices` parameter.
  final List<(String, String)> choices;

  /// Creates metadata for a model field with the specified configuration.
  const FieldMeta({
    required this.name,
    required this.columnName,
    required this.kind,
    this.nullable = false,
    this.primaryKey = false,
    this.auto = false,
    this.unique = false,
    this.dbIndex = false,
    this.defaultVal = const DefaultValue.none(),
    this.maxLength,
    this.verboseName,
    this.helpText,
    this.choices = const [],
  });
}

/// Metadata for a relation between two models.
///
/// Mirrors `djangors_orm::meta::RelationMeta`.
class RelationMeta {
  /// The name of the relation field on the Dart class.
  final String fieldName;

  /// The relationship kind (e.g. ForeignKey).
  final RelationKind kind;

  /// Late-bound target model metadata function. Resolves ordering circularity.
  final ModelMeta Function() target;

  /// The referential integrity delete rule. Django's `on_delete`.
  final OnDelete onDelete;

  /// The name to use for the relation from the related object back to this one. Django's `related_name`.
  final String? relatedName;

  /// Creates relation metadata with target model metadata provider [target] and delete rule [onDelete].
  const RelationMeta({
    required this.fieldName,
    required this.kind,
    required this.target,
    this.onDelete = OnDelete.cascade,
    this.relatedName,
  });
}

/// Metadata for an explicit database index.
///
/// Mirrors `djangors_orm::meta::IndexMeta`.
class IndexMeta {
  /// The name of the index in the database.
  final String name;

  /// The fields included in this index.
  final List<String> fields;

  /// Creates index metadata for index [name] on [fields].
  const IndexMeta({
    required this.name,
    required this.fields,
  });
}

/// Runtime metadata for a model.
///
/// Mirrors `djangors_orm::meta::ModelMeta`.
class ModelMeta {
  /// The name of the Dart class representing this model.
  final String structName;

  /// The app label defining the logical namespace. Django's `app_label`.
  final String appLabel;

  /// The database table name. Django's `db_table`.
  final String tableName;

  /// Fields defined on this model.
  final List<FieldMeta> fields;

  /// Relations defined on this model.
  final List<RelationMeta> relations;

  /// Indexes defined on this model.
  final List<IndexMeta> indexes;

  /// Unique constraints across multiple fields. Django's `unique_together`.
  final List<List<String>> uniqueTogether;

  /// The default ordering for querysets. Django's `ordering`.
  final List<String> ordering;

  /// Creates model metadata describing a database entity.
  const ModelMeta({
    required this.structName,
    required this.appLabel,
    required this.tableName,
    this.fields = const [],
    this.relations = const [],
    this.indexes = const [],
    this.uniqueTogether = const [],
    this.ordering = const [],
  });

  /// Looks up a field by Dart property [name] or database column name.
  FieldMeta? findField(String name) {
    for (final f in fields) {
      if (f.name == name || f.columnName == name) return f;
    }
    return null;
  }

  /// Returns the primary key field metadata.
  ///
  /// Throws [StateError] if no primary key field is defined on this model.
  FieldMeta get primaryKeyField {
    for (final f in fields) {
      if (f.primaryKey) return f;
    }
    throw StateError('Model $structName has no primary key defined');
  }
}

