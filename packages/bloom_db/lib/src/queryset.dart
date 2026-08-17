// lib/src/queryset.dart
import 'dart:async';
import 'database.dart';
import 'dialect.dart';
import 'errors.dart';
import 'expr.dart';
import 'meta.dart';
import 'model.dart';

/// Lazily constructed database query builder for model [T].
///
/// Mirrors `djangors_orm::queryset::QuerySet<T>`.
class QuerySet<T extends Model> {
  final ModelMeta _meta;
  final ModelFromRow<T> _fromRow;
  final List<BloomExpr> _filters;
  final List<(String, bool)> _orderBy; // (columnName, descending)
  final int? _limit;
  final int? _offset;

  /// Creates a [QuerySet] builder for model [T] with given [meta] and row deserializer [fromRow].
  QuerySet({
    required ModelMeta meta,
    required ModelFromRow<T> fromRow,
    List<BloomExpr>? filters,
    List<(String, bool)>? orderBy,
    int? limit,
    int? offset,
  })  : _meta = meta,
        _fromRow = fromRow,
        _filters = filters != null ? List.unmodifiable(filters) : const [],
        _orderBy = orderBy != null ? List.unmodifiable(orderBy) : const [],
        _limit = limit,
        _offset = offset;


  /// Clones the current QuerySet with modified attributes.
  QuerySet<T> _copyWith({
    List<BloomExpr>? filters,
    List<(String, bool)>? orderBy,
    int? limit,
    int? offset,
  }) {
    return QuerySet<T>(
      meta: _meta,
      fromRow: _fromRow,
      filters: filters ?? _filters,
      orderBy: orderBy ?? _orderBy,
      limit: limit ?? _limit,
      offset: offset ?? _offset,
    );
  }

  /// Adds a filter expression or map of field criteria to this queryset.
  QuerySet<T> filter(dynamic expr) {
    final resolved = _resolveExpression(expr);
    return _copyWith(filters: [..._filters, resolved]);
  }

  /// Excludes rows matching [expr] — the negation of [filter].
  QuerySet<T> exclude(dynamic expr) {
    final resolved = _resolveExpression(expr);
    return _copyWith(filters: [..._filters, BloomExpr.not(resolved)]);
  }

  /// Orders results by the given [field] name. A leading `'-'` specifies descending order.
  ///
  /// Throws [BloomOrmFieldNotFoundError] if [field] does not exist on the model.
  QuerySet<T> orderBy(String field) => order_by(field);

  /// Snake_case alias matching Rust `order_by`.
  ///
  /// Throws [BloomOrmFieldNotFoundError] if [field] does not exist on the model.
  QuerySet<T> order_by(String field) {

    final isDesc = field.startsWith('-');
    final cleanField = isDesc ? field.substring(1) : field;
    final f = _meta.findField(cleanField);
    if (f == null) {
      throw BloomOrmFieldNotFoundError(
        field: cleanField,
        model: _meta.structName,
      );
    }
    final colName = f.columnName;
    return _copyWith(orderBy: [..._orderBy, (colName, isDesc)]);
  }

  /// Restricts the maximum number of rows returned by the query.
  QuerySet<T> limit(int n) => _copyWith(limit: n);

  /// Sets the number of rows to skip before starting to return rows.
  QuerySet<T> offset(int n) => _copyWith(offset: n);

  /// Resolves an input filter into a fully validated [BloomExpr].
  BloomExpr _resolveExpression(dynamic expr) {
    if (expr is BloomExpr) {
      return expr;
    }
    if (expr is Map<String, dynamic>) {
      final subExprs = <BloomExpr>[];
      for (final entry in expr.entries) {
        final (fieldName, suffix) = splitFieldLookup(entry.key);
        final f = _meta.findField(fieldName);
        if (f == null) {
          throw BloomOrmFieldNotFoundError(
            field: fieldName,
            model: _meta.structName,
          );
        }
        subExprs.add(BloomExpr.compare(
          field: f.columnName,
          op: suffixToOp(suffix),
          value: BloomValue.from(entry.value),
        ));
      }
      return BloomExpr.and(subExprs);
    }
    if (expr is UnresolvedExpr) {
      return _resolveUnresolvedExpr(expr);
    }
    throw BloomOrmInvalidQueryError('Unsupported filter type: ${expr.runtimeType}');
  }

  BloomExpr _resolveUnresolvedExpr(UnresolvedExpr expr) {
    return switch (expr) {
      UnresolvedCompare(:final field, :final value) => () {
          final (fieldName, suffix) = splitFieldLookup(field);
          final f = _meta.findField(fieldName);
          if (f == null) {
            throw BloomOrmFieldNotFoundError(
              field: fieldName,
              model: _meta.structName,
            );
          }
          return BloomExpr.compare(
            field: f.columnName,
            op: suffixToOp(suffix),
            value: value,
          );
        }(),
      UnresolvedFieldCompare(:final left, :final right) => () {
          final (leftName, suffix) = splitFieldLookup(left);
          final leftF = _meta.findField(leftName);
          final rightF = _meta.findField(right);
          if (leftF == null) {
            throw BloomOrmFieldNotFoundError(
              field: leftName,
              model: _meta.structName,
            );
          }
          if (rightF == null) {
            throw BloomOrmFieldNotFoundError(
              field: right,
              model: _meta.structName,
            );
          }
          return BloomExpr.compareField(
            left: leftF.columnName,
            op: suffixToOp(suffix),
            right: rightF.columnName,
          );
        }(),
      UnresolvedAll(:final nodes) =>
        BloomExpr.and(nodes.map(_resolveUnresolvedExpr).toList()),
      UnresolvedAny(:final nodes) =>
        BloomExpr.or(nodes.map(_resolveUnresolvedExpr).toList()),
      UnresolvedNegate(:final inner) =>
        BloomExpr.not(_resolveUnresolvedExpr(inner)),
    };
  }

  /// Compiles this queryset to a parameterized `SELECT` SQL string and parameter list.
  (String, List<dynamic>) compileSelectWithOrder(
    String selectList,
    bool includeOrder,
    Dialect dialect,
  ) {
    final buffer = StringBuffer('SELECT $selectList FROM "${_meta.tableName}"');
    final params = <dynamic>[];
    var paramIdx = 1;

    String fieldToCol(String name) {
      final f = _meta.findField(name);
      return f != null ? '"${f.columnName}"' : '"$name"';
    }

    if (_filters.isNotEmpty) {
      final combined = BloomExpr.and(_filters);
      final whereSql = _compileExprSql(
        combined,
        _meta.tableName,
        fieldToCol,
        params,
        () => paramIdx++,
        dialect,
      );
      buffer.write(' WHERE $whereSql');
    }

    if (includeOrder) {
      final orderSource = _orderBy.isNotEmpty
          ? _orderBy
          : _meta.ordering.map((field) {
              final isDesc = field.startsWith('-');
              final clean = isDesc ? field.substring(1) : field;
              final f = _meta.findField(clean);
              final col = f != null ? f.columnName : clean;
              return (col, isDesc);
            }).toList();

      if (orderSource.isNotEmpty) {
        final parts = orderSource.map((e) {
          final dir = e.$2 ? 'DESC' : 'ASC';
          return '"${e.$1}" $dir';
        }).toList();
        buffer.write(' ORDER BY ${parts.join(', ')}');
      }
    }

    if (_limit != null) {
      buffer.write(' LIMIT $_limit');
    }
    if (_offset != null) {
      if (_limit == null && dialect.type == DialectType.sqlite) {
        buffer.write(' LIMIT -1');
      }
      buffer.write(' OFFSET $_offset');
    }

    return (buffer.toString(), params);
  }

  static String _compileExprSql(
    BloomExpr expr,
    String tableName,
    String Function(String) fieldToCol,
    List<dynamic> params,
    int Function() nextParamIdx,
    Dialect dialect,
  ) {
    switch (expr) {
      case BloomCompareExpr(:final field, :final op, :final value):
        final col = fieldToCol(field);
        if (op == CompareOp.isIn) {
          final items = switch (value) {
            BloomListValue(:final items) => items,
            _ => [value],
          };
          if (items.isEmpty) {
            return 'FALSE';
          }
          final placeholders = items.map((item) {
            params.add(item.raw);
            return dialect.placeholder(nextParamIdx());
          }).toList();
          return '$col IN (${placeholders.join(', ')})';
        }
        if (op == CompareOp.isNull) {
          final wantNull = value.raw != false;
          return wantNull ? '$col IS NULL' : '$col IS NOT NULL';
        }

        final (opSql, bindVal) = switch (op) {
          CompareOp.ne => ('<>', value.raw),
          CompareOp.eq => ('=', value.raw),
          CompareOp.lt => ('<', value.raw),
          CompareOp.lte => ('<=', value.raw),
          CompareOp.gt => ('>', value.raw),
          CompareOp.gte => ('>=', value.raw),
          CompareOp.regex => ('~', value.raw),
          CompareOp.iregex => ('~*', value.raw),
          CompareOp.iexact => (dialect.ilike, value.raw),
          CompareOp.contains => ('LIKE', '%${value.raw}%'),
          CompareOp.icontains => (dialect.ilike, '%${value.raw}%'),
          CompareOp.startsWith => ('LIKE', '${value.raw}%'),
          CompareOp.endsWith => ('LIKE', '%${value.raw}'),
          CompareOp.isIn || CompareOp.isNull => throw StateError('Handled above'),
        };

        params.add(bindVal);
        final ph = dialect.placeholder(nextParamIdx());
        return '$col $opSql $ph';

      case BloomAndExpr(:final exprs):
        if (exprs.isEmpty) return 'TRUE';
        final parts = exprs
            .map((e) => '(${_compileExprSql(e, tableName, fieldToCol, params, nextParamIdx, dialect)})')
            .toList();
        return parts.join(' AND ');

      case BloomOrExpr(:final exprs):
        if (exprs.isEmpty) return 'FALSE';
        final parts = exprs
            .map((e) => '(${_compileExprSql(e, tableName, fieldToCol, params, nextParamIdx, dialect)})')
            .toList();
        return parts.join(' OR ');

      case BloomNotExpr(:final inner):
        return 'NOT (${_compileExprSql(inner, tableName, fieldToCol, params, nextParamIdx, dialect)})';

      case BloomCompareFieldExpr(:final left, :final op, :final right):
        final lhs = fieldToCol(left);
        final rhs = fieldToCol(right);
        return switch (op) {
          CompareOp.eq => '$lhs = $rhs',
          CompareOp.ne => '$lhs <> $rhs',
          CompareOp.lt => '$lhs < $rhs',
          CompareOp.lte => '$lhs <= $rhs',
          CompareOp.gt => '$lhs > $rhs',
          CompareOp.gte => '$lhs >= $rhs',
          CompareOp.contains => "$lhs LIKE '%' || $rhs || '%'",
          CompareOp.icontains => "$lhs ${dialect.ilike} '%' || $rhs || '%'",
          CompareOp.startsWith => "$lhs LIKE $rhs || '%'",
          CompareOp.endsWith => "$lhs LIKE '%' || $rhs",
          CompareOp.iexact => "$lhs ${dialect.ilike} $rhs",
          CompareOp.regex => '$lhs ~ $rhs',
          CompareOp.iregex => '$lhs ~* $rhs',
          CompareOp.isIn => throw ArgumentError(
              'isIn is not valid for a field-to-field comparison (F() vs F()); '
              'it requires a list of values, not another field.'),
          CompareOp.isNull => throw ArgumentError(
              'isNull is not valid for a field-to-field comparison (F() vs F()); '
              'it is a unary check on a single field, not a comparison between two fields.'),
        };
    }
  }

  /// Compiles and returns the SQL text and bind parameters for debugging and test inspection.
  (String, List<dynamic>) debugSql([Dialect dialect = Dialect.postgres]) {
    return compileSelectWithOrder('*', true, dialect);
  }

  /// Snake_case alias for [debugSql].
  (String, List<dynamic>) debug_sql([Dialect dialect = Dialect.postgres]) =>
      debugSql(dialect);

  /// Executes the query and returns all matching model instances.
  Future<List<T>> all(DbExecutor db) async {
    final (sql, params) = compileSelectWithOrder('*', true, db.dialect);
    final rows = await db.fetchAll(sql, params);
    return rows.map(_fromRow).toList();
  }

  /// Fetches a single model instance matching the filters.
  ///
  /// Throws [BloomOrmNotFoundError] if no row is found, or
  /// [BloomOrmMultipleObjectsReturnedError] if more than one row matches.
  Future<T> get(DbExecutor db) async {
    final limited = limit(2);
    final results = await limited.all(db);
    if (results.isEmpty) {
      throw BloomOrmNotFoundError(model: _meta.structName);
    }
    if (results.length > 1) {
      throw BloomOrmMultipleObjectsReturnedError(model: _meta.structName);
    }
    return results.first;
  }

  /// Fetches the first model instance matching query filters, or `null` if no row matches.
  Future<T?> first(DbExecutor db) async {
    final limited = limit(1);
    final results = await limited.all(db);
    return results.isEmpty ? null : results.first;
  }

  /// Returns `true` if at least one record matches query filters.
  Future<bool> exists(DbExecutor db) async {
    final (sql, params) = limit(1).compileSelectWithOrder('1', false, db.dialect);
    final row = await db.fetchOptional(sql, params);
    return row != null;
  }

  /// Returns the total count of rows matching query filters.
  Future<int> count(DbExecutor db) async {
    final (sql, params) = compileSelectWithOrder('COUNT(*)', false, db.dialect);
    final row = await db.fetchOne(sql, params);
    return row.tryInt(0) ?? 0;
  }

  /// Executes a bulk UPDATE query on rows matching current filters.
  ///
  /// Supports literal updates and field arithmetic expressions (via [SetExpr] / [F]).
  /// Throws [BloomOrmFieldNotFoundError] if any field in [sets] is not defined on the model.
  Future<int> update(DbExecutor db, Map<String, dynamic> sets) async {
    if (sets.isEmpty) return 0;
    final dialect = db.dialect;
    final setClauses = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    String fieldToCol(String name) {
      final f = _meta.findField(name);
      return f != null ? '"${f.columnName}"' : '"$name"';
    }

    for (final entry in sets.entries) {
      final f = _meta.findField(entry.key);
      if (f == null) {
        throw BloomOrmFieldNotFoundError(
          field: entry.key,
          model: _meta.structName,
        );
      }
      final lhsCol = '"${f.columnName}"';
      final setExpr = SetExpr.from(entry.value);

      switch (setExpr) {
        case LiteralSetExpr(:final value):
          setClauses.add('$lhsCol = ${dialect.placeholder(paramIdx++)}');
          params.add(value.raw);
        case FieldOpSetExpr(:final field, :final op, :final operand):
          final rhsF = _meta.findField(field);
          if (rhsF == null) {
            throw BloomOrmFieldNotFoundError(
              field: field,
              model: _meta.structName,
            );
          }
          final rhsCol = '"${rhsF.columnName}"';
          final opSql = switch (op) {
            ArithOp.add => '+',
            ArithOp.sub => '-',
            ArithOp.mul => '*',
            ArithOp.div => '/',
          };
          setClauses.add('$lhsCol = $rhsCol $opSql ${dialect.placeholder(paramIdx++)}');
          params.add(operand.raw);
      }
    }

    final buffer = StringBuffer('UPDATE "${_meta.tableName}" SET ${setClauses.join(', ')}');
    if (_filters.isNotEmpty) {
      final combined = BloomExpr.and(_filters);
      final whereSql = _compileExprSql(
        combined,
        _meta.tableName,
        fieldToCol,
        params,
        () => paramIdx++,
        dialect,
      );
      buffer.write(' WHERE $whereSql');
    }

    return await db.execute(buffer.toString(), params);
  }

  /// Deletes all rows matching current filters, returning rows deleted count.
  Future<int> delete(DbExecutor db) async {
    final dialect = db.dialect;
    final params = <dynamic>[];
    var paramIdx = 1;

    String fieldToCol(String name) {
      final f = _meta.findField(name);
      return f != null ? '"${f.columnName}"' : '"$name"';
    }

    final buffer = StringBuffer('DELETE FROM "${_meta.tableName}"');
    if (_filters.isNotEmpty) {
      final combined = BloomExpr.and(_filters);
      final whereSql = _compileExprSql(
        combined,
        _meta.tableName,
        fieldToCol,
        params,
        () => paramIdx++,
        dialect,
      );
      buffer.write(' WHERE $whereSql');
    }

    return await db.execute(buffer.toString(), params);
  }

  /// Low-level INSERT query returning the generated primary key.
  ///
  /// Throws [BloomOrmFieldNotFoundError] if any field in [values] does not exist on [meta].
  static Future<int> insertRaw(
    DbExecutor db,
    ModelMeta meta,
    Map<String, dynamic> values,
  ) async {
    final dialect = db.dialect;
    final pkField = meta.primaryKeyField;
    final pkCol = pkField.columnName;

    final cols = <String>[];
    final placeholders = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    for (final entry in values.entries) {
      final f = meta.findField(entry.key);
      if (f == null) {
        throw BloomOrmFieldNotFoundError(
          field: entry.key,
          model: meta.structName,
        );
      }
      if (f.auto) continue;
      cols.add('"${f.columnName}"');
      placeholders.add(dialect.placeholder(paramIdx++));
      params.add(entry.value);
    }

    final sql = cols.isEmpty
        ? 'INSERT INTO "${meta.tableName}" DEFAULT VALUES RETURNING "$pkCol"'
        : 'INSERT INTO "${meta.tableName}" (${cols.join(', ')}) VALUES (${placeholders.join(', ')}) RETURNING "$pkCol"';

    final row = await db.fetchOne(sql, params);
    return row.tryIntByName(pkCol) ?? row.tryInt(0) ?? 0;
  }

  /// Inserts many rows in a single multi-row INSERT statement and returns generated primary keys.
  static Future<List<int>> bulkCreate<M extends Model>(
    DbExecutor db,
    ModelMeta meta,
    List<M> items,
  ) async {
    if (items.isEmpty) return const [];
    final dialect = db.dialect;
    final pkField = meta.primaryKeyField;
    final pkCol = pkField.columnName;

    final firstValues = items.first.fieldValues();
    final insertableFields = <String>[];
    final insertableCols = <String>[];

    for (final (name, _) in firstValues) {
      final f = meta.findField(name);
      if (f != null && !f.auto) {
        insertableFields.add(name);
        insertableCols.add('"${f.columnName}"');
      }
    }

    final placeholderGroups = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    for (final item in items) {
      final valuesMap = {for (final (k, v) in item.fieldValues()) k: v.raw};
      final rowPh = <String>[];
      for (final fieldName in insertableFields) {
        rowPh.add(dialect.placeholder(paramIdx++));
        params.add(valuesMap[fieldName]);
      }
      placeholderGroups.add('(${rowPh.join(', ')})');
    }

    final sql =
        'INSERT INTO "${meta.tableName}" (${insertableCols.join(', ')}) VALUES ${placeholderGroups.join(', ')} RETURNING "$pkCol"';

    final rows = await db.fetchAll(sql, params);
    return rows.map((r) => r.tryIntByName(pkCol) ?? r.tryInt(0) ?? 0).toList();
  }

  /// Snake_case alias for [bulkCreate].
  static Future<List<int>> bulk_create<M extends Model>(
    DbExecutor db,
    ModelMeta meta,
    List<M> items,
  ) =>
      bulkCreate<M>(db, meta, items);

  /// Fetches the first row matching current filter, or creates a new one from [defaults].
  ///
  /// Returns `(T, true)` when created, `(T, false)` when already existed.
  Future<(T, bool)> getOrCreate(
    DbExecutor db, {
    required Map<String, dynamic> defaults,
  }) async {
    final existing = await first(db);
    if (existing != null) {
      return (existing, false);
    }
    final pk = await insertRaw(db, _meta, defaults);
    final pkCol = _meta.primaryKeyField.name;
    final created = await _copyWith(filters: []).filter({pkCol: pk}).get(db);
    return (created, true);
  }

  /// Snake_case alias for [getOrCreate].
  Future<(T, bool)> get_or_create(
    DbExecutor db, {
    required Map<String, dynamic> defaults,
  }) =>
      getOrCreate(db, defaults: defaults);

  /// Like [getOrCreate] but updates existing rows with [updates].
  Future<(T, bool)> updateOrCreate(
    DbExecutor db, {
    required Map<String, dynamic> defaults,
    required Map<String, dynamic> updates,
  }) async {
    final existing = await first(db);
    if (existing != null) {
      await update(db, updates);
      final pkCol = _meta.primaryKeyField.name;
      final pkVal = (existing.fieldValues().firstWhere((v) => v.$1 == pkCol)).$2.raw;
      final updated = await _copyWith(filters: []).filter({pkCol: pkVal}).get(db);
      return (updated, false);
    }
    final pk = await insertRaw(db, _meta, defaults);
    final pkCol = _meta.primaryKeyField.name;
    final created = await _copyWith(filters: []).filter({pkCol: pk}).get(db);
    return (created, true);
  }

  /// Snake_case alias for [updateOrCreate].
  Future<(T, bool)> update_or_create(
    DbExecutor db, {
    required Map<String, dynamic> defaults,
    required Map<String, dynamic> updates,
  }) =>
      updateOrCreate(db, defaults: defaults, updates: updates);

  /// Selects only specified [fields], returning raw maps of column values — Django's `.values()`.
  ///
  /// Throws [BloomOrmInvalidQueryError] if [fields] is empty, or [BloomOrmFieldNotFoundError] if a field is not found.
  Future<List<Map<String, dynamic>>> values(
    DbExecutor db, [
    List<String>? fields,
  ]) async {
    final selectedFields = fields ?? _meta.fields.map((f) => f.name).toList();
    if (selectedFields.isEmpty) {
      throw BloomOrmInvalidQueryError('values requires at least one field');
    }
    for (final f in selectedFields) {
      if (_meta.findField(f) == null) {
        throw BloomOrmFieldNotFoundError(field: f, model: _meta.structName);
      }
    }
    final selectList = selectedFields.map((f) {
      final fieldMeta = _meta.findField(f)!;
      return '"${fieldMeta.columnName}" AS "$f"';
    }).join(', ');

    final (sql, params) = compileSelectWithOrder(selectList, true, db.dialect);
    final rows = await db.fetchAll(sql, params);
    return rows.map((r) => r.toMap()).toList();
  }

  /// Selects a single field as a flat list of values — Django's `.values_list(field, flat=True)`.
  ///
  /// Throws [BloomOrmFieldNotFoundError] if [field] does not exist on the model.
  Future<List<dynamic>> valuesList(
    DbExecutor db,
    String field, {
    bool flat = true,
  }) async {
    final f = _meta.findField(field);
    if (f == null) {
      throw BloomOrmFieldNotFoundError(field: field, model: _meta.structName);
    }
    final selectList = '"${f.columnName}"';
    final (sql, params) = compileSelectWithOrder(selectList, true, db.dialect);
    final rows = await db.fetchAll(sql, params);
    return rows.map((r) => r.toMap().values.first).toList();
  }

  /// Snake_case alias for [valuesList].
  ///
  /// Throws [BloomOrmFieldNotFoundError] if [field] does not exist on the model.
  Future<List<dynamic>> values_list(
    DbExecutor db,
    String field, {
    bool flat = true,
  }) =>
      valuesList(db, field, flat: flat);
}

