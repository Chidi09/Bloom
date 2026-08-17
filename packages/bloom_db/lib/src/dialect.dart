// lib/src/dialect.dart

/// Supported SQL dialects.
enum DialectType {
  /// PostgreSQL dialect.
  postgres,

  /// SQLite dialect.
  sqlite,
}

/// Abstract SQL dialect abstraction handling syntax differences between databases.
///
/// Mirrors `djangors_db::Dialect`.
abstract class Dialect {
  /// Base const constructor for dialects.
  const Dialect();

  /// The enum identifier for this dialect.
  DialectType get type;

  /// Returns the parameter placeholder for this dialect at 1-based [index].
  ///
  /// Postgres: `$1`, `$2`, ...
  /// SQLite: `?`
  String placeholder(int index);

  /// Returns the case-insensitive LIKE operator keyword.
  ///
  /// Postgres: `ILIKE`
  /// SQLite: `LIKE`
  String get ilike;

  /// Quotes an SQL identifier [name] with double quotes.
  String quoteIdent(String name) => '"$name"';

  /// Casts an SQL [expr] to a floating point type.
  ///
  /// Postgres: `$expr::float8`
  /// SQLite: `CAST($expr AS REAL)`
  String castFloat(String expr);

  /// Column type for an auto-incrementing integer primary key.
  String get autoPkType;

  /// Column type for a timezone-aware timestamp.
  String get timestampType;

  /// SQL expression for the current timestamp.
  String get currentTimestamp;

  /// Column type for binary blob data.
  String get byteaType;

  /// Pre-instantiated PostgreSQL dialect instance.
  static const Dialect postgres = PostgresDialect();

  /// Pre-instantiated SQLite dialect instance.
  static const Dialect sqlite = SqliteDialect();

  /// Infers the database dialect from a database [url] string without connecting.
  static Dialect fromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('sqlite:') ||
        trimmed.startsWith('sqlite3:') ||
        trimmed.endsWith('.db') ||
        trimmed.endsWith('.sqlite') ||
        trimmed == ':memory:' ||
        trimmed == 'sqlite::memory:') {
      return sqlite;
    }
    return postgres;
  }
}

/// PostgreSQL database dialect implementation.
class PostgresDialect extends Dialect {
  /// Creates a PostgreSQL dialect instance.
  const PostgresDialect();

  @override
  DialectType get type => DialectType.postgres;

  @override
  String placeholder(int index) => '\$$index';

  @override
  String get ilike => 'ILIKE';

  @override
  String castFloat(String expr) => '$expr::float8';

  @override
  String get autoPkType => 'BIGSERIAL PRIMARY KEY';

  @override
  String get timestampType => 'TIMESTAMPTZ';

  @override
  String get currentTimestamp => 'now()';

  @override
  String get byteaType => 'BYTEA';

  @override
  String toString() => 'Dialect.postgres';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PostgresDialect;

  @override
  int get hashCode => DialectType.postgres.hashCode;
}

/// SQLite database dialect implementation.
class SqliteDialect extends Dialect {
  /// Creates an SQLite dialect instance.
  const SqliteDialect();

  @override
  DialectType get type => DialectType.sqlite;

  @override
  String placeholder(int index) => '?';

  @override
  String get ilike => 'LIKE';

  @override
  String castFloat(String expr) => 'CAST($expr AS REAL)';

  @override
  String get autoPkType => 'INTEGER PRIMARY KEY AUTOINCREMENT';

  @override
  String get timestampType => 'TEXT';

  @override
  String get currentTimestamp => 'CURRENT_TIMESTAMP';

  @override
  String get byteaType => 'BLOB';

  @override
  String toString() => 'Dialect.sqlite';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SqliteDialect;

  @override
  int get hashCode => DialectType.sqlite.hashCode;
}

