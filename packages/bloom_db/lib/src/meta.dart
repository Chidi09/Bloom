// lib/src/meta.dart

/// Represents database column types supported by the Bloom ORM.
///
/// Encapsulates column data types across PostgreSQL and SQLite, including variable-length strings,
/// integers, timestamps, booleans, UUIDs, decimals, and binary data.
///
/// Mirrors `djangors_orm::meta::FieldKind`.
///
/// Example:
/// ```dart
/// const pkKind = FieldKind.bigInt;
/// const nameKind = FieldKind.char;
/// const priceKind = FieldKind.decimal(precision: 10, scale: 2);
/// ```
sealed class FieldKind {
  /// Base const constructor for field kinds.
  const FieldKind();

  /// Text field with a maximum length (`VARCHAR(N)`). Django's `CharField`.
  static const char = _SimpleFieldKind('char');

  /// Unbounded text field (`TEXT`). Django's `TextField`.
  static const text = _SimpleFieldKind('text');

  /// A path/key stored in a configured file storage backend. Django's `FileField`.
  static const fileField = _SimpleFieldKind('fileField');

  /// Standard 32-bit signed integer (`INTEGER` / `INT4`). Django's `IntegerField`.
  static const integer = _SimpleFieldKind('integer');

  /// 64-bit signed integer (`BIGINT` / `INT8`). Django's `BigIntegerField`.
  static const bigInt = _SimpleFieldKind('bigInt');

  /// 64-bit floating point number (`DOUBLE PRECISION` / `REAL`). Django's `FloatField`.
  static const float = _SimpleFieldKind('float');

  /// Boolean field (`BOOLEAN` or `INTEGER 0/1`). Django's `BooleanField`.
  static const boolean = _SimpleFieldKind('boolean');

  /// Date-only field (`DATE`). Django's `DateField`.
  static const date = _SimpleFieldKind('date');

  /// Timezone-aware date and time field (`TIMESTAMPTZ` / `TEXT`). Django's `DateTimeField`.
  static const dateTime = _SimpleFieldKind('dateTime');

  /// Time-of-day field (`TIME`). Django's `TimeField`.
  static const time = _SimpleFieldKind('time');

  /// Duration / delta interval field. Django's `DurationField`.
  static const duration = _SimpleFieldKind('duration');

  /// Universally unique identifier (`UUID` or `TEXT`). Django's `UUIDField`.
  static const uuid = _SimpleFieldKind('uuid');

  /// Email address string field with validation semantics. Django's `EmailField`.
  static const email = _SimpleFieldKind('email');

  /// URL string field with validation semantics. Django's `URLField`.
  static const url = _SimpleFieldKind('url');

  /// URL-safe slug string field. Django's `SlugField`.
  static const slug = _SimpleFieldKind('slug');

  /// IPv4/IPv6 network address field (`INET` or `TEXT`). Django's `GenericIPAddressField`.
  static const ip = _SimpleFieldKind('ip');

  /// Raw binary data field (`BYTEA` / `BLOB`). Django's `BinaryField`.
  static const binary = _SimpleFieldKind('binary');

  /// JSON-encoded structured data field (`JSONB` / `TEXT`). Django's `JSONField`.
  static const json = _SimpleFieldKind('json');

  /// Fixed-precision decimal number with [precision] total digits and [scale] decimal places (`DECIMAL(p, s)`).
  /// Django's `DecimalField`.
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

/// Fixed-precision decimal field kind with [precision] total digits and [scale] decimal places.
///
/// Example:
/// ```dart
/// const priceKind = DecimalFieldKind(precision: 12, scale: 4);
/// assert(priceKind.precision == 12);
/// assert(priceKind.scale == 4);
/// ```
class DecimalFieldKind extends FieldKind {
  /// The maximum total number of digits stored in the decimal value.
  final int precision;

  /// The number of decimal digits stored to the right of the decimal point.
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

/// Represents the default schema value of a model field when omitted during insertion.
///
/// Mirrors `djangors_orm::meta::DefaultValue`.
///
/// Example:
/// ```dart
/// const defaultAge = DefaultValue.i64(0);
/// const defaultActive = DefaultValue.boolVal(true);
/// const noDefault = DefaultValue.none();
/// ```
sealed class DefaultValue {
  /// Base const constructor for default values.
  const DefaultValue();

  /// 64-bit integer default [value].
  const factory DefaultValue.i64(int value) = _I64DefaultValue;

  /// Floating point default [value].
  const factory DefaultValue.f64(double value) = _F64DefaultValue;

  /// Text string default [value].
  const factory DefaultValue.text(String value) = _TextDefaultValue;

  /// Boolean default [value].
  const factory DefaultValue.boolVal(bool value) = _BoolDefaultValue;

  /// No default value specified (field requires explicit value or is nullable).
  const factory DefaultValue.none() = _NoneDefaultValue;

  /// Returns the underlying raw Dart value, or `null` if [DefaultValue.none].
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

/// The cardinality and kind of relation between models.
///
/// Mirrors `djangors_orm::meta::RelationKind`.
enum RelationKind {
  /// Many-to-one foreign key relationship (`ForeignKey`).
  foreignKey,

  /// One-to-one relationship (`OneToOneField`).
  oneToOne,

  /// Many-to-many relationship with an intermediary join table (`ManyToManyField`).
  manyToMany,
}

/// Action to take on related rows when a referenced primary key object is deleted.
///
/// Mirrors `djangors_orm::meta::OnDelete`.
enum OnDelete {
  /// Cascade delete: automatically delete dependent rows. Django's `CASCADE`.
  cascade,

  /// Prevent deletion by raising an integrity error if dependents exist. Django's `PROTECT`.
  protect,

  /// Set the foreign key column to `NULL` on dependent rows. Django's `SET_NULL`.
  setNull,

  /// Prevent deletion conforming to standard SQL RESTRICT. Django's `RESTRICT`.
  restrict,

  /// Take no action in the database. Django's `DO_NOTHING`.
  doNothing,
}

/// Runtime schema metadata for a single model field or database column.
///
/// Mirrors `djangors_orm::meta::FieldMeta`.
///
/// Example:
/// ```dart
/// const emailMeta = FieldMeta(
///   name: 'email',
///   columnName: 'email_address',
///   kind: FieldKind.char,
///   maxLength: 255,
///   unique: true,
///   dbIndex: true,
/// );
/// ```
class FieldMeta {
  /// The name of the field on the Dart class.
  final String name;

  /// The database column name for this field in SQL tables.
  final String columnName;

  /// The database column data type.
  final FieldKind kind;

  /// Whether the column allows `NULL` values in the database.
  final bool nullable;

  /// Whether this field serves as the entity's primary key.
  final bool primaryKey;

  /// Whether the column is auto-generated or auto-incremented by the database.
  final bool auto;

  /// Whether values in this column must be unique across all rows.
  final bool unique;

  /// Whether a database index should be created for this column.
  final bool dbIndex;

  /// The default value for the field when omitted during insertion.
  final DefaultValue defaultVal;

  /// The maximum character length for string columns (`VARCHAR(maxLength)`).
  final int? maxLength;

  /// Human-readable label for UI forms and admin dashboards.
  final String? verboseName;

  /// Descriptive helper text for forms and documentation.
  final String? helpText;

  /// Allowed choices for field values, stored as (db_value, display_label) tuples.
  final List<(String, String)> choices;

  /// Creates metadata for a model field with the specified configuration.
  ///
  /// - [name]: Dart field property name.
  /// - [columnName]: SQL column name in the database table.
  /// - [kind]: Database data type [FieldKind].
  /// - [nullable]: Whether `NULL` is allowed (defaults to `false`).
  /// - [primaryKey]: Whether this is the primary key (defaults to `false`).
  /// - [auto]: Whether auto-generated on insert (defaults to `false`).
  /// - [unique]: Enforces unique constraint (defaults to `false`).
  /// - [dbIndex]: Generates column index (defaults to `false`).
  /// - [defaultVal]: Fallback default value (defaults to [DefaultValue.none]).
  /// - [maxLength]: Maximum string length.
  /// - [verboseName]: Display name.
  /// - [helpText]: Helper description.
  /// - [choices]: Value-label tuples for enumerated choices.
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

/// Metadata describing a relationship between two model entities.
///
/// Mirrors `djangors_orm::meta::RelationMeta`.
///
/// Example:
/// ```dart
/// final authorRelation = RelationMeta(
///   fieldName: 'author',
///   kind: RelationKind.foreignKey,
///   target: () => User.meta,
///   onDelete: OnDelete.cascade,
///   relatedName: 'posts',
/// );
/// ```
class RelationMeta {
  /// The name of the relation field on the Dart model class.
  final String fieldName;

  /// The relationship kind (e.g. [RelationKind.foreignKey], [RelationKind.manyToMany]).
  final RelationKind kind;

  /// Late-bound target model metadata function to resolve circular dependencies between models.
  final ModelMeta Function() target;

  /// Referential integrity deletion action rule.
  final OnDelete onDelete;

  /// The reverse relation accessor name exposed on the target model (e.g. `'user.posts'`).
  final String? relatedName;

  /// Creates relation metadata with target model provider [target] and delete rule [onDelete].
  const RelationMeta({
    required this.fieldName,
    required this.kind,
    required this.target,
    this.onDelete = OnDelete.cascade,
    this.relatedName,
  });
}

/// Metadata describing an explicit database table index.
///
/// Mirrors `djangors_orm::meta::IndexMeta`.
///
/// Example:
/// ```dart
/// const emailIndex = IndexMeta(
///   name: 'idx_users_email_status',
///   fields: ['email', 'status'],
/// );
/// ```
class IndexMeta {
  /// The identifier name of the index in the database schema.
  final String name;

  /// The list of field names covered by this composite or specialized index.
  final List<String> fields;

  /// Creates index metadata for index [name] spanning [fields].
  const IndexMeta({
    required this.name,
    required this.fields,
  });
}

/// Runtime schema and mapping metadata for a database model entity.
///
/// Contains table names, field descriptors, relations, indexes, constraints, and default ordering.
///
/// Mirrors `djangors_orm::meta::ModelMeta`.
///
/// Example:
/// ```dart
/// const userMeta = ModelMeta(
///   structName: 'User',
///   appLabel: 'auth',
///   tableName: 'auth_users',
///   fields: [
///     FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
///     FieldMeta(name: 'name', columnName: 'name', kind: FieldKind.char),
///   ],
///   ordering: ['-id'],
/// );
/// ```
class ModelMeta {
  /// The name of the Dart class representing this model (e.g. `'User'`).
  final String structName;

  /// The application namespace label (e.g. `'auth'`, `'blog'`).
  final String appLabel;

  /// The physical database table name (e.g. `'auth_users'`).
  final String tableName;

  /// Column field descriptors defined on this model.
  final List<FieldMeta> fields;

  /// Relationships to other models defined on this entity.
  final List<RelationMeta> relations;

  /// Explicit database indexes configured for this table.
  final List<IndexMeta> indexes;

  /// Multi-field unique constraints (`unique_together`).
  final List<List<String>> uniqueTogether;

  /// Default ordering fields for queries when no explicit `.orderBy()` is specified.
  final List<String> ordering;

  /// Creates model metadata describing a database entity schema.
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

  /// Looks up a [FieldMeta] descriptor by Dart property [name] or database column name.
  ///
  /// Returns `null` if no matching field is defined on this model.
  FieldMeta? findField(String name) {
    for (final f in fields) {
      if (f.name == name || f.columnName == name) return f;
    }
    return null;
  }

  /// Returns the primary key [FieldMeta] descriptor.
  ///
  /// Throws [StateError] if no field with `primaryKey: true` is defined on this model.
  FieldMeta get primaryKeyField {
    for (final f in fields) {
      if (f.primaryKey) return f;
    }
    throw StateError('Model $structName has no primary key defined');
  }
}


