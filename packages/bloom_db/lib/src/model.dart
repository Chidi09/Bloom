// lib/src/model.dart
import 'database.dart';
import 'expr.dart';
import 'meta.dart';

/// Base interface for all Bloom ORM models.
///
/// Mirrors `djangors_orm::meta::Model`.
abstract class Model {
  /// The runtime metadata for this model.
  ModelMeta get modelMeta;

  /// Returns every field's (name, value) in declaration order.
  List<(String, BloomValue)> fieldValues();

  /// Converts the model instance into a map of column names to raw values.
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

/// Type signature for a function instantiating a model [T] from a [DbRow].
typedef ModelFromRow<T> = T Function(DbRow row);
