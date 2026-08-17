// lib/src/database_cache.dart
import 'dart:convert';
import 'package:bloom_db/bloom_db.dart';
import 'cache.dart';

/// A database-backed [BloomCache] implementation that persists cached entries in
/// an SQL database table using Bloom's unified [DbExecutor] abstraction.
///
/// Works seamlessly with both PostgreSQL ([PostgresDbExecutor]) and SQLite ([SqliteDbExecutor]).
/// Stored values are encoded as JSON strings, and entry expiration timestamps are stored
/// in a timezone-aware timestamp column.
class DatabaseCache extends BloomCache {
  /// The underlying database executor from `package:bloom_db`.
  final DbExecutor db;

  /// The name of the table used to store cache entries.
  final String tableName;

  bool _initialized = false;

  /// Creates a [DatabaseCache] using the provided [db] executor.
  ///
  /// [tableName] defaults to `'bloom_cache_entries'`.
  DatabaseCache(this.db, {this.tableName = 'bloom_cache_entries'});

  /// Lazily ensures that the cache table exists in the database.
  Future<void> ensureTable() async {
    if (_initialized) return;

    final timestampType = db.dialect.timestampType;
    final sql = 'CREATE TABLE IF NOT EXISTS $tableName ('
        'key TEXT PRIMARY KEY, '
        'value TEXT NOT NULL, '
        'expires_at $timestampType'
        ')';
    await db.execute(sql);
    _initialized = true;
  }

  @override
  Future<T?> get<T>(String key) async {
    await ensureTable();

    final p1 = db.dialect.placeholder(1);
    final sql = 'SELECT value, expires_at FROM $tableName WHERE key = $p1';
    final row = await db.fetchOptional(sql, [key]);

    if (row == null) {
      return null;
    }

    // TTL Expiration Check on Read
    final expiresAt = row.tryDateTimeByName('expires_at') ?? row.tryDateTime(1);
    if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
      await delete(key);
      return null;
    }

    final rawValue = row.tryStringByName('value') ?? row.tryString(0);
    if (rawValue == null) return null;

    return decodeCacheValue<T>(rawValue);
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    await ensureTable();

    final expiresAt = ttl != null ? DateTime.now().toUtc().add(ttl) : null;
    final rawValue = jsonEncode(value);

    final p1 = db.dialect.placeholder(1);
    final p2 = db.dialect.placeholder(2);
    final p3 = db.dialect.placeholder(3);

    final sql = 'INSERT INTO $tableName (key, value, expires_at) '
        'VALUES ($p1, $p2, $p3) '
        'ON CONFLICT (key) DO UPDATE SET '
        'value = EXCLUDED.value, '
        'expires_at = EXCLUDED.expires_at';

    await db.execute(sql, [key, rawValue, expiresAt]);
  }

  @override
  Future<void> delete(String key) async {
    await ensureTable();

    final p1 = db.dialect.placeholder(1);
    final sql = 'DELETE FROM $tableName WHERE key = $p1';
    await db.execute(sql, [key]);
  }

  @override
  Future<void> clear() async {
    await ensureTable();

    final sql = 'DELETE FROM $tableName';
    await db.execute(sql);
  }

  /// Deletes all expired entries from the cache table in a single query.
  Future<int> pruneExpired() async {
    await ensureTable();

    final p1 = db.dialect.placeholder(1);
    final sql = 'DELETE FROM $tableName WHERE expires_at IS NOT NULL AND expires_at < $p1';
    return await db.execute(sql, [DateTime.now().toUtc()]);
  }
}
