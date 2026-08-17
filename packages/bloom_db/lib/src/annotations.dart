// lib/src/annotations.dart
import 'meta.dart';

/// Class-level annotation marking a class as a Bloom ORM Model.
class BloomModel {
  /// The app label namespace. Defaults to snake_case of the package or class module.
  final String? app;

  /// The explicit database table name. Defaults to `{app}_{model_name}`.
  final String? tableName;

  /// Creates a [@BloomModel] annotation with optional [app] namespace and [tableName] override.
  const BloomModel({
    this.app,
    this.tableName,
  });
}

/// Field-level annotation defining database column properties.
class BloomField {
  /// Custom database column name. Defaults to snake_case of the field name.
  final String? column;

  /// Explicit field kind if not inferred from Dart type.
  final FieldKind? kind;

  /// Whether the field is nullable in the database.
  final bool nullable;

  /// Whether this field is the primary key.
  final bool primaryKey;

  /// Whether this field is auto-generated/auto-incremented.
  final bool auto;

  /// Whether values in this column must be unique.
  final bool unique;

  /// Whether an index should be created on this column.
  final bool dbIndex;

  /// Default value for the column.
  final DefaultValue defaultVal;

  /// Maximum length for string/char columns.
  final int? maxLength;

  /// Human-readable label for admin and UI.
  final String? verboseName;

  /// Helper text for forms and documentation.
  final String? helpText;

  /// Defines column configuration for a model property.
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

/// Helper constant for auto-incrementing integer primary keys.
const idField = BloomField(
  primaryKey: true,
  auto: true,
  kind: FieldKind.bigInt,
);

