// lib/src/queryset.dart
import 'dart:async';
import 'database.dart';
import 'dialect.dart';
import 'errors.dart';
import 'expr.dart';
import 'meta.dart';
import 'model.dart';

/// Immutable, lazily evaluated database query builder for model entity [T].
///
/// A [QuerySet] represents a collection of database queries constructed fluently via
/// `.filter()`, `.exclude()`, `.orderBy()`, `.limit()`, and `.offset()`. QuerySets are immutable;
/// modifying methods return a new [QuerySet] instance with updated parameters.
///
/// SQL queries are compiled and dispatched to the database only when invoking terminal execution
/// methods: [all], [get], [first], [exists], [count], [update], [delete], [getOrCreate], [values],
/// or [valuesList].
///
/// Mirrors `djangors_orm::queryset::QuerySet<T>`.
///
/// Example:
/// ```dart
/// final qs = QuerySet<User>(meta: User.meta, fromRow: User.fromRow);
///
/// // Fluent filtering and ordering
/// final activeUsers = await qs
///     .filter(Q('age__gte', 18) & Q('is_active', true))
///     .orderBy('-created_at')
///     .limit(20)
///     .all(db);
///
/// // Single object lookup
/// final user = await qs.filter({'email': 'alice@example.com'}).get(db);
/// ```
class QuerySet<T extends Model> {
  final ModelMeta _meta;
  final ModelFromRow<T> _fromRow;
  final List<BloomExpr> _filters;
  final List<(String, bool)> _orderBy; // (columnName, descending)
  final int? _limit;
  final int? _offset;

  /// Creates an immutable [QuerySet] builder for model [T].
  ///
  /// - [meta]: Runtime schema metadata for model entity [T].
  /// - [fromRow]: Factory deserializer constructing a [T] instance from a [DbRow].
  /// - [filters]: Optional initial list of resolved [BloomExpr] criteria.
  /// - [orderBy]: Optional initial list of `(columnName, descending)` order rules.
  /// - [limit]: Optional row limit cap.
  /// - [offset]: Optional row offset count.
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

  /// Returns a new [QuerySet] with the added filter criteria [expr].
  ///
  /// [expr] can be:
  /// - An [UnresolvedExpr] constructed with [Q] or [QF] (e.g. `Q('age__gte', 21)`)
  /// - A [Map<String, dynamic>] of field lookups (e.g. `{'status': 'active', 'age__gte': 18}`)
  /// - A pre-resolved [BloomExpr]
  ///
  /// Throws [BloomOrmFieldNotFoundError] if any referenced field does not exist on the model.
  /// Throws [BloomOrmInvalidQueryError] if [expr] is of an unsupported type.
  ///
  /// Example:
  /// ```dart
  /// final activeAdults = qs.filter(Q('age__gte', 18) & Q('is_active', true));
  /// final byMap = qs.filter({'is_active': true, 'age__lt': 65});
  /// ```
  QuerySet<T> filter(dynamic expr) {
    final resolved = _resolveExpression(expr);
    return _copyWith(filters: [..._filters, resolved]);
  }

  /// Returns a new [QuerySet] excluding records matching [expr] (negation of [filter]).
  ///
  /// Example:
  /// ```dart
  /// final nonBanned = qs.exclude(Q('is_banned', true));
  /// ```
  QuerySet<T> exclude(dynamic expr) {
    final resolved = _resolveExpression(expr);
    return _copyWith(filters: [..._filters, BloomExpr.not(resolved)]);
  }

  /// Returns a new [QuerySet] ordered by the given model [field].
  ///
  /// Prefixing [field] with `'-'` specifies descending order (e.g. `'-created_at'`).
  ///
  /// Throws [BloomOrmFieldNotFoundError] if [field] does not exist on the model.
  ///
  /// Example:
  /// ```dart
  /// final sorted = qs.orderBy('name').orderBy('-created_at');
  /// ```
  QuerySet<T> orderBy(String field) => order_by(field);

  /// Snake_case alias for [orderBy], matching Django/Rust ORM conventions.
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

  /// Returns a new [QuerySet] restricting the maximum number of returned rows to [n].
  ///
  /// Example:
  /// ```dart
  /// final topTen = qs.orderBy('-score').limit(10);
  /// ```
  QuerySet<T> limit(int n) {
    if (n < 0) {
      throw ArgumentError.value(
          n, 'n', 'limit must be greater than or equal to 0');
    }
    return _copyWith(limit: n);
  }

  /// Returns a new [QuerySet] skipping the first [n] rows of query results.
  ///
  /// Example:
  /// ```dart
  /// final pageTwo = qs.limit(10).offset(10);
  /// ```
  QuerySet<T> offset(int n) {
    if (n < 0) {
      throw ArgumentError.value(
          n, 'n', 'offset must be greater than or equal to 0');
    }
    return _copyWith(offset: n);
  }

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
    throw BloomOrmInvalidQueryError(
        'Unsupported filter type: ${expr.runtimeType}');
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

  /// Compiles this queryset into a parameterized `SELECT` SQL string and parameter list.
  ///
  /// - [selectList]: SQL column projection string (e.g. `'*'`, `'COUNT(*)'`, `'"id", "name"'`).
  /// - [includeOrder]: Whether to append `ORDER BY` clauses to the generated SQL.
  /// - [dialect]: Database [Dialect] determining placeholders, escaping, and type casts.
  ///
  /// Returns a record `(sql, parameters)`.
  (String, List<dynamic>) compileSelectWithOrder(
    String selectList,
    bool includeOrder,
    Dialect dialect, {
    bool includePaging = true,
  }) {
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

    if (includePaging) {
      if (_limit != null) {
        buffer.write(' LIMIT $_limit');
      }
      if (_offset != null) {
        if (_limit == null && dialect.type == DialectType.sqlite) {
          buffer.write(' LIMIT -1');
        }
        buffer.write(' OFFSET $_offset');
      }
    }

    return (buffer.toString(), params);
  }

  /// Escapes LIKE wildcard characters (`%`, `_`) and the escape character
  /// itself so user input in substring lookups matches literally.
  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
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

        final rawText = value.raw.toString();
        final escaped = _escapeLike(rawText);
        final (opSql, bindVal, needsEscape) = switch (op) {
          CompareOp.ne => ('<>', value.raw, false),
          CompareOp.eq => ('=', value.raw, false),
          CompareOp.lt => ('<', value.raw, false),
          CompareOp.lte => ('<=', value.raw, false),
          CompareOp.gt => ('>', value.raw, false),
          CompareOp.gte => ('>=', value.raw, false),
          CompareOp.regex => _regexOperator(dialect, '~', value.raw),
          CompareOp.iregex => _regexOperator(dialect, '~*', value.raw),
          // LIKE-family: user input is escaped so `%`/`_` match literally.
          CompareOp.iexact => (dialect.ilike, escaped, true),
          CompareOp.contains => ('LIKE', '%$escaped%', true),
          CompareOp.icontains => (dialect.ilike, '%$escaped%', true),
          CompareOp.startsWith => ('LIKE', '$escaped%', true),
          CompareOp.endsWith => ('LIKE', '%$escaped', true),
          CompareOp.isIn ||
          CompareOp.isNull =>
            throw StateError('Handled above'),
        };

        params.add(bindVal);
        final ph = dialect.placeholder(nextParamIdx());
        final escapeClause = needsEscape ? " ESCAPE '\\'" : '';
        return '$col $opSql $ph$escapeClause';

      case BloomAndExpr(:final exprs):
        if (exprs.isEmpty) return 'TRUE';
        final parts = exprs
            .map((e) =>
                '(${_compileExprSql(e, tableName, fieldToCol, params, nextParamIdx, dialect)})')
            .toList();
        return parts.join(' AND ');

      case BloomOrExpr(:final exprs):
        if (exprs.isEmpty) return 'FALSE';
        final parts = exprs
            .map((e) =>
                '(${_compileExprSql(e, tableName, fieldToCol, params, nextParamIdx, dialect)})')
            .toList();
        return parts.join(' OR ');

      case BloomNotExpr(:final inner):
        return 'NOT (${_compileExprSql(inner, tableName, fieldToCol, params, nextParamIdx, dialect)})';

      case BloomCompareFieldExpr(:final left, :final op, :final right):
        final lhs = fieldToCol(left);
        final rhs = fieldToCol(right);
        if ((op == CompareOp.regex || op == CompareOp.iregex) &&
            dialect.type == DialectType.sqlite) {
          throw BloomOrmInvalidQueryError(
              'regex/iregex lookups are not supported by SQLite');
        }
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

  static (String, dynamic, bool) _regexOperator(
      Dialect dialect, String operator, dynamic value) {
    if (dialect.type == DialectType.sqlite) {
      throw BloomOrmInvalidQueryError(
          'regex/iregex lookups are not supported by SQLite');
    }
    return (operator, value, false);
  }

  /// Compiles and returns the SQL text and bind parameters for debugging and test inspection.
  ///
  /// - [dialect]: Database dialect to compile for (defaults to [Dialect.postgres]).
  ///
  /// Example:
  /// ```dart
  /// final (sql, params) = qs.filter(Q('age__gte', 18)).debugSql(Dialect.sqlite);
  /// print('Generated SQL: $sql with params: $params');
  /// ```
  (String, List<dynamic>) debugSql([Dialect dialect = Dialect.postgres]) {
    return compileSelectWithOrder('*', true, dialect);
  }

  /// Snake_case alias for [debugSql].
  (String, List<dynamic>) debug_sql([Dialect dialect = Dialect.postgres]) =>
      debugSql(dialect);

  /// Executes the compiled query against [db] and returns all matching model instances as a [List<T>].
  ///
  /// Throws [BloomOrmQueryException] if query execution fails.
  ///
  /// Example:
  /// ```dart
  /// final users = await qs.filter(Q('is_active', true)).all(db);
  /// ```
  Future<List<T>> all(DbExecutor db) async {
    final (sql, params) = compileSelectWithOrder('*', true, db.dialect);
    final rows = await db.fetchAll(sql, params);
    return rows.map(_fromRow).toList();
  }

  /// Fetches a single model instance matching the queryset filters from [db].
  ///
  /// Throws [BloomOrmNotFoundError] if zero matching records are found.
  /// Throws [BloomOrmMultipleObjectsReturnedError] if more than one matching record is found.
  /// Throws [BloomOrmQueryException] on database driver failure.
  ///
  /// Example:
  /// ```dart
  /// final admin = await qs.filter(Q('email', 'admin@example.com')).get(db);
  /// ```
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

  /// Fetches the first model instance matching query filters from [db], or returns `null` if no records match.
  ///
  /// Throws [BloomOrmQueryException] on database driver failure.
  ///
  /// Example:
  /// ```dart
  /// final newest = await qs.orderBy('-created_at').first(db);
  /// if (newest != null) print(newest.id);
  /// ```
  Future<T?> first(DbExecutor db) async {
    final limited = limit(1);
    final results = await limited.all(db);
    return results.isEmpty ? null : results.first;
  }

  /// Checks whether at least one record matching query filters exists in the database [db].
  ///
  /// Compiles an optimized `SELECT 1 ... LIMIT 1` query.
  ///
  /// Example:
  /// ```dart
  /// final hasBanned = await qs.filter(Q('is_banned', true)).exists(db);
  /// ```
  Future<bool> exists(DbExecutor db) async {
    final (sql, params) =
        limit(1).compileSelectWithOrder('1', false, db.dialect);
    final row = await db.fetchOptional(sql, params);
    return row != null;
  }

  /// Returns the total count of rows matching query filters in the database [db].
  ///
  /// Compiles a `SELECT COUNT(*) FROM ...` aggregation query. Slicing
  /// (`limit`/`offset`) is ignored: the count covers the whole filtered set,
  /// so a paged queryset (e.g. with `OFFSET` beyond the row count) still
  /// returns the total instead of throwing [BloomOrmNotFoundError].
  ///
  /// Example:
  /// ```dart
  /// final count = await qs.filter(Q('status', 'active')).count(db);
  /// ```
  Future<int> count(DbExecutor db) async {
    final (sql, params) = compileSelectWithOrder(
      'COUNT(*)',
      false,
      db.dialect,
      includePaging: false,
    );
    final row = await db.fetchOne(sql, params);
    return row.tryInt(0) ?? 0;
  }

  /// Executes a bulk `UPDATE` query on all rows matching current queryset filters.
  ///
  /// [sets] maps field names to new values or expressions. Supports both literal values and
  /// database-side field arithmetic expressions using [F] (e.g. `{'score': F('score') + 10}`).
  ///
  /// Throws [BloomOrmFieldNotFoundError] if any key in [sets] is not defined on the model.
  /// Throws [BloomOrmInvalidQueryError] if the queryset has no filters and
  /// [allowUnfiltered] is false (default) — bulk-updating a whole table with
  /// one call is almost always a bug. Pass `allowUnfiltered: true` to
  /// acknowledge a deliberate table-wide update.
  /// Throws [BloomOrmQueryException] if underlying query execution fails.
  ///
  /// Returns the number of affected database rows.
  ///
  /// Example:
  /// ```dart
  /// final updated = await qs.filter(Q('status', 'pending')).update(db, {
  ///   'status': 'processed',
  ///   'attempts': F('attempts') + 1,
  /// });
  /// ```
  Future<int> update(
    DbExecutor db,
    Map<String, dynamic> sets, {
    bool allowUnfiltered = false,
  }) async {
    if (sets.isEmpty) return 0;
    if (_filters.isEmpty && !allowUnfiltered) {
      throw BloomOrmInvalidQueryError(
        'Refusing to UPDATE "${_meta.tableName}" without filters. '
        'Add .filter(...) or pass allowUnfiltered: true.',
      );
    }
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
          setClauses.add(
              '$lhsCol = $rhsCol $opSql ${dialect.placeholder(paramIdx++)}');
          params.add(operand.raw);
      }
    }

    final buffer = StringBuffer(
        'UPDATE "${_meta.tableName}" SET ${setClauses.join(', ')}');
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

  /// Deletes all database records matching the current queryset filters.
  ///
  /// Throws [BloomOrmInvalidQueryError] if the queryset has no filters and
  /// [allowUnfiltered] is false (default) — wiping a whole table with one
  /// call is almost always a bug. Pass `allowUnfiltered: true` to acknowledge
  /// a deliberate table-wide delete.
  ///
  /// Returns the total count of deleted database rows.
  /// Throws [BloomOrmQueryException] if statement execution fails.
  ///
  /// Example:
  /// ```dart
  /// final deletedCount = await qs.filter(Q('is_expired', true)).delete(db);
  /// ```
  Future<int> delete(DbExecutor db, {bool allowUnfiltered = false}) async {
    if (_filters.isEmpty && !allowUnfiltered) {
      throw BloomOrmInvalidQueryError(
        'Refusing to DELETE FROM "${_meta.tableName}" without filters. '
        'Add .filter(...) or pass allowUnfiltered: true.',
      );
    }
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

  /// Low-level `INSERT` statement execution returning the generated primary key value.
  ///
  /// - [db]: Active [DbExecutor] connection.
  /// - [meta]: Target model schema metadata.
  /// - [values]: Map of column or field names to raw values. Auto-increment columns are omitted.
  ///
  /// Returns the generated primary key (typically [int] or [String]).
  /// Throws [BloomOrmFieldNotFoundError] if any key in [values] is missing from [meta].
  ///
  /// Example:
  /// ```dart
  /// final newId = await QuerySet.insertRaw(db, User.meta, {
  ///   'name': 'Bob',
  ///   'email': 'bob@example.com',
  /// });
  /// ```
  static Future<dynamic> insertRaw(
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
    if (pkField.kind == FieldKind.integer || pkField.kind == FieldKind.bigInt) {
      return row.tryIntByName(pkCol) ?? row.tryInt(0) ?? 0;
    }
    return row.tryStringByName(pkCol) ??
        row.tryIntByName(pkCol) ??
        row[pkCol] ??
        row[0];
  }

  /// Inserts multiple model [items] in a single multi-row `INSERT ... VALUES (...), (...) RETURNING` statement.
  ///
  /// - [db]: Database executor.
  /// - [meta]: Target model schema metadata.
  /// - [items]: List of model entity instances to insert.
  ///
  /// Returns a list of generated primary keys corresponding to [items].
  /// Returns empty list if [items] is empty.
  ///
  /// Example:
  /// ```dart
  /// final ids = await QuerySet.bulkCreate(db, User.meta, [user1, user2, user3]);
  /// ```
  static Future<List<dynamic>> bulkCreate<M extends Model>(
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
    final isIntPk =
        pkField.kind == FieldKind.integer || pkField.kind == FieldKind.bigInt;
    return rows.map((r) {
      if (isIntPk) {
        return r.tryIntByName(pkCol) ?? r.tryInt(0) ?? 0;
      }
      return r.tryStringByName(pkCol) ??
          r.tryIntByName(pkCol) ??
          r[pkCol] ??
          r[0];
    }).toList();
  }

  /// Snake_case alias for [bulkCreate].
  static Future<List<dynamic>> bulk_create<M extends Model>(
    DbExecutor db,
    ModelMeta meta,
    List<M> items,
  ) =>
      bulkCreate<M>(db, meta, items);

  /// Fetches the first record matching current queryset filters, or creates a new record using [defaults].
  ///
  /// Returns a record `(instance, created)` where `created` is `true` if a new row was inserted,
  /// or `false` if an existing row was retrieved.
  ///
  /// Example:
  /// ```dart
  /// final (user, wasCreated) = await qs
  ///     .filter({'email': 'alice@example.com'})
  ///     .getOrCreate(db, defaults: {'name': 'Alice', 'email': 'alice@example.com'});
  /// ```
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

  /// Fetches the first record matching current queryset filters, updating it with [updates],
  /// or creates a new record using [defaults] if none was found.
  ///
  /// Returns a record `(instance, created)` where `created` is `true` if created, or `false` if updated.
  ///
  /// Example:
  /// ```dart
  /// final (user, wasCreated) = await qs
  ///     .filter({'email': 'alice@example.com'})
  ///     .updateOrCreate(
  ///       db,
  ///       defaults: {'name': 'Alice', 'email': 'alice@example.com', 'login_count': 1},
  ///       updates: {'login_count': F('login_count') + 1},
  ///     );
  /// ```
  Future<(T, bool)> updateOrCreate(
    DbExecutor db, {
    required Map<String, dynamic> defaults,
    required Map<String, dynamic> updates,
  }) async {
    final existing = await first(db);
    if (existing != null) {
      await update(db, updates);
      final pkCol = _meta.primaryKeyField.name;
      final pkVal =
          (existing.fieldValues().firstWhere((v) => v.$1 == pkCol)).$2.raw;
      final updated =
          await _copyWith(filters: []).filter({pkCol: pkVal}).get(db);
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

  /// Selects only the specified [fields], returning raw maps of field names to values — Django's `.values()`.
  ///
  /// If [fields] is omitted or `null`, all model fields are selected.
  ///
  /// Throws [BloomOrmInvalidQueryError] if [fields] is explicitly empty.
  /// Throws [BloomOrmFieldNotFoundError] if any field in [fields] is not found on the model.
  ///
  /// Example:
  /// ```dart
  /// final rows = await qs.filter(Q('is_active', true)).values(db, ['id', 'email']);
  /// for (final r in rows) {
  ///   print('${r["id"]}: ${r["email"]}');
  /// }
  /// ```
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

  /// Selects a single model [field] — Django's `.values_list(field, flat=...)`.
  ///
  /// When [flat] is `true` (the default), returns a bare list of values:
  ///
  /// ```dart
  /// final emails = await qs.filter(Q('is_active', true)).valuesList(db, 'email');
  /// print(emails); // ['alice@example.com', 'bob@example.com']
  /// ```
  ///
  /// When [flat] is `false`, returns one single-entry map per row instead
  /// (`{field: value}` — the same shape as `.values(db, [field])`), keeping the
  /// result addressable by field name:
  ///
  /// ```dart
  /// final rows = await qs.valuesList(db, 'email', flat: false);
  /// print(rows); // [{'email': 'alice@example.com'}, {'email': 'bob@example.com'}]
  /// ```
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
    if (flat) {
      return rows.map((r) => r.toMap().values.first).toList();
    }
    return rows.map((r) => {field: r.toMap().values.first}).toList();
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
