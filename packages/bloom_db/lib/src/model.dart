// lib/src/model.dart
import 'database.dart';
import 'expr.dart';
import 'meta.dart';

/// Base abstract class for all Bloom ORM entity models.
///
/// Models expose schema descriptors via [modelMeta], serialize their attributes via
/// [fieldValues] and [toRow], and integrate with [QuerySet] for type-safe database queries.
///
/// Mirrors `djangors_orm::meta::Model`.
///
/// Example:
/// ```dart
/// class User extends Model {
///   final int id;
///   final String name;
///   final String email;
///
///   User({required this.id, required this.name, required this.email});
///
///   static const meta = ModelMeta(
///     structName: 'User',
///     appLabel: 'auth',
///     tableName: 'auth_users',
///     fields: [
///       FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
///       FieldMeta(name: 'name', columnName: 'name', kind: FieldKind.char),
///       FieldMeta(name: 'email', columnName: 'email', kind: FieldKind.char),
///     ],
///   );
///
///   @override
///   ModelMeta get modelMeta => meta;
///
///   @override
///   List<(String, BloomValue)> fieldValues() => [
///     ('id', BloomValue.i64(id)),
///     ('name', BloomValue.text(name)),
///     ('email', BloomValue.text(email)),
///   ];
///
///   static User fromRow(DbRow row) => User(
///     id: row.tryIntByName('id') ?? 0,
///     name: row.tryStringByName('name') ?? '',
///     email: row.tryStringByName('email') ?? '',
///   );
/// }
/// ```
abstract class Model {
  /// The runtime [ModelMeta] schema metadata describing this model entity.
  ModelMeta get modelMeta;

  /// Returns every field's `(fieldName, BloomValue)` tuple in declaration order.
  List<(String, BloomValue)> fieldValues();

  /// Converts this model instance into a map of database column names to raw values.
  ///
  /// Resolves Dart property names to physical database column names via [modelMeta].
  ///
  /// Example:
  /// ```dart
  /// final rowMap = user.toRow();
  /// print(rowMap['email_address']);
  /// ```
  Map<String, dynamic> toRow() {
    final values = fieldValues();
    final meta = modelMeta;
    final map = <String, dynamic>{};
    for (final (fieldName, val) in values) {
      final f = meta.findField(fieldName);
      final colName = f != null ? f.columnName : fieldName;
      map[colName] = val.raw;
    }
    return map;
  }
}

/// Type signature for a factory function instantiating a strongly typed model [T] from a [DbRow].
///
/// Used by [QuerySet] to deserialize database query results into Dart entity objects.
///
/// Example:
/// ```dart
/// final ModelFromRow<User> userFactory = (DbRow row) => User(
///   id: row.tryIntByName('id') ?? 0,
///   name: row.tryStringByName('name') ?? '',
/// );
/// ```
typedef ModelFromRow<T> = T Function(DbRow row);

