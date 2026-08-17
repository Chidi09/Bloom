// lib/src/database.dart
import 'dart:async';
import 'package:postgres/postgres.dart' as pg;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'dialect.dart';
import 'errors.dart';

/// Database row abstraction representing a single row returned by a query.
///
/// Mirrors `djangors_db::DbRow`.
abstract class DbRow {
  /// Access a column value by column name (String) or 0-based column index (int).
  dynamic operator [](dynamic columnOrIndex);

  /// Decodes an integer value from column at [idx] or returns null.
  int? tryInt(int idx);

  /// Decodes an integer value from column [name] or returns null.
  int? tryIntByName(String name);

  /// Decodes a floating-point value from column at [idx] or returns null.
  double? tryDouble(int idx);

  /// Decodes a floating-point value from column [name] or returns null.
  double? tryDoubleByName(String name);

  /// Decodes a string value from column at [idx] or returns null.
  String? tryString(int idx);

  /// Decodes a string value from column [name] or returns null.
  String? tryStringByName(String name);

  /// Decodes a boolean value from column at [idx] or returns null.
  bool? tryBool(int idx);

  /// Decodes a boolean value from column [name] or returns null.
  bool? tryBoolByName(String name);

  /// Decodes a UTC [DateTime] value from column at [idx] or returns null.
  DateTime? tryDateTime(int idx);

  /// Decodes a UTC [DateTime] value from column [name] or returns null.
  DateTime? tryDateTimeByName(String name);

  /// Decodes a byte list from column at [idx] or returns null.
  List<int>? tryBytes(int idx);

  /// Decodes a byte list from column [name] or returns null.
  List<int>? tryBytesByName(String name);

  /// Converts the row into a Map of column name to value.
  Map<String, dynamic> toMap();
}

/// A generic map-backed [DbRow] implementation.
class MapDbRow implements DbRow {
  final Map<String, dynamic> _data;
  final List<dynamic> _indexedValues;

  /// Creates a [MapDbRow] backed by a map of column names to values.
  MapDbRow(Map<String, dynamic> data)
      : _data = Map.unmodifiable(data),
        _indexedValues = List.unmodifiable(data.values);

  /// Creates a [MapDbRow] from parallel lists of [columnNames] and [values].
  MapDbRow.fromIndexed(List<String> columnNames, List<dynamic> values)
      : _indexedValues = List.unmodifiable(values),
        _data = Map.unmodifiable({
          for (var i = 0; i < columnNames.length && i < values.length; i++)
            columnNames[i]: values[i]
        });


  @override
  dynamic operator [](dynamic columnOrIndex) {
    if (columnOrIndex is int) {
      if (columnOrIndex >= 0 && columnOrIndex < _indexedValues.length) {
        return _indexedValues[columnOrIndex];
      }
      return null;
    }
    return _data[columnOrIndex.toString()];
  }

  @override
  int? tryInt(int idx) => _toInt(this[idx]);

  @override
  int? tryIntByName(String name) => _toInt(this[name]);

  @override
  double? tryDouble(int idx) => _toDouble(this[idx]);

  @override
  double? tryDoubleByName(String name) => _toDouble(this[name]);

  @override
  String? tryString(int idx) => this[idx]?.toString();

  @override
  String? tryStringByName(String name) => this[name]?.toString();

  @override
  bool? tryBool(int idx) => _toBool(this[idx]);

  @override
  bool? tryBoolByName(String name) => _toBool(this[name]);

  @override
  DateTime? tryDateTime(int idx) => _toDateTime(this[idx]);

  @override
  DateTime? tryDateTimeByName(String name) => _toDateTime(this[name]);

  @override
  List<int>? tryBytes(int idx) => _toBytes(this[idx]);

  @override
  List<int>? tryBytesByName(String name) => _toBytes(this[name]);

  @override
  Map<String, dynamic> toMap() => _data;

  @override
  String toString() => 'DbRow($_data)';

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    if (v is BigInt) return v.toInt();
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final l = v.toLowerCase();
      return l == 't' || l == 'true' || l == '1';
    }
    return null;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String) {
      return DateTime.tryParse(v)?.toUtc();
    }
    return null;
  }

  static List<int>? _toBytes(dynamic v) {
    if (v == null) return null;
    if (v is List<int>) return v;
    if (v is List) return v.cast<int>();
    return null;
  }
}

/// Unified database execution interface across backends.
///
/// Mirrors `djangors_db::DbExecutor`.
abstract class DbExecutor {
  /// The database dialect in use.
  Dialect get dialect;

  /// Executes a query and returns all matching rows.
  Future<List<DbRow>> fetchAll(String sql, [List<dynamic> parameters = const []]);

  /// Executes a query and returns exactly one row, throwing [BloomOrmNotFoundError] if no row.
  Future<DbRow> fetchOne(String sql, [List<dynamic> parameters = const []]);

  /// Executes a query and returns an optional row (null if empty).
  Future<DbRow?> fetchOptional(String sql, [List<dynamic> parameters = const []]);

  /// Executes a DML/DDL statement and returns the number of affected rows.
  Future<int> execute(String sql, [List<dynamic> parameters = const []]);

  /// Records a query for logging/telemetry.
  void recordQuery(String sql, [List<dynamic> parameters = const []]);

  /// History of recorded queries.
  List<String> get queryLog;

  /// Closes the database connection.
  Future<void> close();
}

/// SQLite executor implementation wrapping `package:sqlite3`.
class SqliteDbExecutor implements DbExecutor {
  final sqlite.Database _db;
  final bool _shouldClose;
  final List<String> _queryLog = [];

  /// Creates a [SqliteDbExecutor] wrapping an active sqlite [_db] instance.
  ///
  /// Set [shouldClose] to false to prevent [close] from disposing the underlying sqlite database.
  SqliteDbExecutor(this._db, {bool shouldClose = true})
      : _shouldClose = shouldClose;

  /// Opens an in-memory SQLite database.
  factory SqliteDbExecutor.inMemory() {
    final db = sqlite.sqlite3.openInMemory();
    return SqliteDbExecutor(db);
  }

  /// Opens a SQLite database file at [path].
  factory SqliteDbExecutor.openFile(String path) {
    final db = sqlite.sqlite3.open(path);
    return SqliteDbExecutor(db);
  }


  @override
  Dialect get dialect => Dialect.sqlite;

  @override
  List<String> get queryLog => List.unmodifiable(_queryLog);

  @override
  void recordQuery(String sql, [List<dynamic> parameters = const []]) {
    _queryLog.add(sql);
  }

  List<Object?> _sanitizeParams(List<dynamic> parameters) {
    return parameters.map((p) {
      if (p == null) return null;
      if (p is DateTime) return p.toUtc().toIso8601String();
      if (p is bool) return p ? 1 : 0;
      if (p is num || p is String || p is List<int>) return p;
      return p.toString();
    }).toList();
  }

  @override
  Future<List<DbRow>> fetchAll(
      String sql, [List<dynamic> parameters = const []]) async {
    recordQuery(sql, parameters);
    try {
      final sanitized = _sanitizeParams(parameters);
      final resultSet = _db.select(sql, sanitized);
      final colNames = resultSet.columnNames;
      return resultSet.map((r) {
        return MapDbRow.fromIndexed(colNames, r.values);
      }).toList();
    } catch (e, st) {
      throw BloomOrmQueryException(e, st);
    }
  }

  @override
  Future<DbRow> fetchOne(
      String sql, [List<dynamic> parameters = const []]) async {
    final rows = await fetchAll(sql, parameters);
    if (rows.isEmpty) {
      throw BloomOrmNotFoundError(model: 'row');
    }
    return rows.first;
  }

  @override
  Future<DbRow?> fetchOptional(
      String sql, [List<dynamic> parameters = const []]) async {
    final rows = await fetchAll(sql, parameters);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  @override
  Future<int> execute(String sql, [List<dynamic> parameters = const []]) async {
    recordQuery(sql, parameters);
    try {
      final sanitized = _sanitizeParams(parameters);
      _db.execute(sql, sanitized);
      return _db.updatedRows;
    } catch (e, st) {
      throw BloomOrmQueryException(e, st);
    }
  }

  @override
  Future<void> close() async {
    if (_shouldClose) {
      _db.dispose();
    }
  }
}

/// PostgreSQL executor implementation wrapping `package:postgres`.
class PostgresDbExecutor implements DbExecutor {
  final pg.Connection _conn;
  final List<String> _queryLog = [];

  /// Creates a [PostgresDbExecutor] wrapping an established postgres [_conn] connection.
  PostgresDbExecutor(this._conn);

  /// Connects to a PostgreSQL database using connection parameters.

  static Future<PostgresDbExecutor> connect({
    required String host,
    required String database,
    required String username,
    String? password,
    int port = 5432,
    pg.SslMode sslMode = pg.SslMode.disable,
  }) async {
    final endpoint = pg.Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
    final conn = await pg.Connection.open(
      endpoint,
      settings: pg.ConnectionSettings(sslMode: sslMode),
    );
    return PostgresDbExecutor(conn);
  }

  /// Connects via a postgres connection URL string.
  static Future<PostgresDbExecutor> connectUrl(String url) async {
    final uri = Uri.parse(url);
    final userInfo = uri.userInfo.split(':');
    final username = userInfo.isNotEmpty ? userInfo[0] : 'postgres';
    final password = userInfo.length > 1 ? userInfo[1] : null;
    final database =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres';

    return connect(
      host: uri.host.isNotEmpty ? uri.host : 'localhost',
      port: uri.hasPort ? uri.port : 5432,
      database: database,
      username: username,
      password: password,
    );
  }

  @override
  Dialect get dialect => Dialect.postgres;

  @override
  List<String> get queryLog => List.unmodifiable(_queryLog);

  @override
  void recordQuery(String sql, [List<dynamic> parameters = const []]) {
    _queryLog.add(sql);
  }

  List<Object?> _sanitizeParams(List<dynamic> parameters) {
    return parameters.map((p) {
      if (p == null) return null;
      if (p is DateTime) return p.toUtc();
      if (p is bool || p is num || p is String || p is List<int>) return p;
      return p.toString();
    }).toList();
  }

  @override
  Future<List<DbRow>> fetchAll(
      String sql, [List<dynamic> parameters = const []]) async {
    recordQuery(sql, parameters);
    try {
      final sanitized = _sanitizeParams(parameters);
      final result = await _conn.execute(sql, parameters: sanitized);
      final columnNames =
          result.schema.columns.map((c) => c.columnName ?? '').toList();

      final rows = <DbRow>[];
      for (final row in result) {
        rows.add(MapDbRow.fromIndexed(columnNames, row));
      }
      return rows;
    } catch (e, st) {
      throw BloomOrmQueryException(e, st);
    }
  }

  @override
  Future<DbRow> fetchOne(
      String sql, [List<dynamic> parameters = const []]) async {
    final rows = await fetchAll(sql, parameters);
    if (rows.isEmpty) {
      throw BloomOrmNotFoundError(model: 'row');
    }
    return rows.first;
  }

  @override
  Future<DbRow?> fetchOptional(
      String sql, [List<dynamic> parameters = const []]) async {
    final rows = await fetchAll(sql, parameters);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  @override
  Future<int> execute(String sql, [List<dynamic> parameters = const []]) async {
    recordQuery(sql, parameters);
    try {
      final sanitized = _sanitizeParams(parameters);
      final result = await _conn.execute(sql, parameters: sanitized);
      return result.affectedRows;
    } catch (e, st) {
      throw BloomOrmQueryException(e, st);
    }
  }

  @override
  Future<void> close() async {
    await _conn.close();
  }
}
