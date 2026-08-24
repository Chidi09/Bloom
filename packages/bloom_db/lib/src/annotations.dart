// lib/src/annotations.dart
import 'meta.dart';

/// Class-level annotation marking a Dart class as a Bloom ORM Model entity.
///
/// Annotate model classes with [@BloomModel] to configure database table mapping,
/// namespace prefixes, and integration with the Bloom code generator and schema migrator.
///
/// Example:
/// ```dart
/// @BloomModel(app: 'auth', tableName: 'auth_users')
/// class User extends Model {
///   @idField
///   final int id;
///
///   @BloomField(maxLength: 150, unique: true)
///   final String email;
///
///   @BloomField(column: 'created_at')
///   final DateTime createdAt;
///
///   User({required this.id, required this.email, required this.createdAt});
/// }
/// ```
class BloomModel {
  /// The application or module label namespace.
  ///
  /// When [tableName] is omitted, table names default to `{app}_{model_snake_case}`.
  final String? app;

  /// The explicit database table name override.
  ///
  /// When omitted, defaults to `{app}_{model_name}` or the snake_case of the class name.
  final String? tableName;

  /// Creates a [@BloomModel] annotation with optional [app] namespace and [tableName] override.
  ///
  /// - [app]: Logical namespace prefix for this model (e.g. `'auth'`, `'billing'`).
  /// - [tableName]: Custom SQL table name (e.g. `'users'`, `'orders'`).
  const BloomModel({
    this.app,
    this.tableName,
  });
}

/// Field-level annotation defining database column properties and constraints.
///
/// Use [@BloomField] on class properties to configure column naming, primary keys,
/// uniqueness, database indexes, default values, nullability, and schema constraints.
///
/// Example:
/// ```dart
/// class Product extends Model {
///   @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
///   final int id;
///
///   @BloomField(column: 'product_sku', maxLength: 50, unique: true, dbIndex: true)
///   final String sku;
///
///   @BloomField(nullable: true, helpText: 'Optional marketing description')
///   final String? description;
///
///   @BloomField(defaultVal: DefaultValue.boolVal(true))
///   final bool isAvailable;
/// }
/// ```
class BloomField {
  /// Custom database column name override.
  ///
  /// Defaults to the snake_case representation of the Dart field name.
  final String? column;

  /// Explicit database column kind if not automatically inferred from the Dart type.
  final FieldKind? kind;

  /// Whether this column allows `NULL` values in the database schema.
  ///
  /// Defaults to `false`.
  final bool nullable;

  /// Whether this field serves as the entity's primary key column.
  ///
  /// Defaults to `false`.
  final bool primaryKey;

  /// Whether this column value is auto-generated or auto-incremented by the database backend.
  ///
  /// When `true`, insert queries omit this field and fetch the generated value via `RETURNING`.
  /// Defaults to `false`.
  final bool auto;

  /// Whether values in this column must be unique across all rows in the table.
  ///
  /// Defaults to `false`.
  final bool unique;

  /// Whether an explicit database index should be created for this column in migrations.
  ///
  /// Defaults to `false`.
  final bool dbIndex;

  /// The default value for this column when omitted during insertion.
  ///
  /// Defaults to [DefaultValue.none()].
  final DefaultValue defaultVal;

  /// Maximum character length for string and character columns (`VARCHAR(maxLength)`).
  final int? maxLength;

  /// Human-readable label for administration dashboards and UI forms.
  final String? verboseName;

  /// Descriptive helper text for developer documentation and generated admin forms.
  final String? helpText;

  /// Defines column configuration, schema constraints, and metadata for a model property.
  ///
  /// Parameters:
  /// - [column]: Custom database column name. Defaults to field snake_case if omitted.
  /// - [kind]: Explicit [FieldKind] data type (e.g. [FieldKind.text], [FieldKind.bigInt]).
  /// - [nullable]: Whether `NULL` values are permitted in this column. Defaults to `false`.
  /// - [primaryKey]: Marks this column as the primary key. Defaults to `false`.
  /// - [auto]: Marks this column as auto-incrementing/auto-generated. Defaults to `false`.
  /// - [unique]: Enforces a `UNIQUE` constraint on this column. Defaults to `false`.
  /// - [dbIndex]: Generates a single-column database index. Defaults to `false`.
  /// - [defaultVal]: Constant fallback value when omitted. Defaults to [DefaultValue.none()].
  /// - [maxLength]: Maximum length for string columns.
  /// - [verboseName]: Display label for UI/admin inspection.
  /// - [helpText]: Form/documentation helper string.
  const BloomField({
    this.column,
    this.kind,
    this.nullable = false,
    this.primaryKey = false,
    this.auto = false,
    this.unique = false,
    this.dbIndex = false,
    this.defaultVal = const DefaultValue.none(),
    this.maxLength,
    this.verboseName,
    this.helpText,
  });
}

/// Convenience constant for auto-incrementing 64-bit integer primary keys.
///
/// Preconfigured with `primaryKey: true`, `auto: true`, and `kind: FieldKind.bigInt`.
///
/// Example:
/// ```dart
/// class Article extends Model {
///   @idField
///   final int id;
/// }
/// ```
const idField = BloomField(
  primaryKey: true,
  auto: true,
  kind: FieldKind.bigInt,
);

