// lib/src/dialect.dart

/// Enumeration of supported SQL database dialects.
enum DialectType {
  /// PostgreSQL database dialect.
  postgres,

  /// SQLite database dialect.
  sqlite,
}

/// Abstract SQL dialect handler encapsulating syntax and type differences across database engines.
///
/// Implemented by [PostgresDialect] and [SqliteDialect] to provide dialect-specific SQL generation
/// for parameter placeholders, case-insensitivity, identifier escaping, type casting, and schema types.
///
/// Mirrors `djangors_db::Dialect`.
///
/// Example:
/// ```dart
/// final dialect = Dialect.fromUrl('sqlite:///tmp/test.db');
/// print(dialect.placeholder(1)); // '?'
///
/// final pgDialect = Dialect.postgres;
/// print(pgDialect.placeholder(1)); // '$1'
/// ```
abstract class Dialect {
  /// Base const constructor for dialect implementations.
  const Dialect();

  /// The [DialectType] enum identifier for this database engine.
  DialectType get type;

  /// Returns the parameter bind placeholder string for this dialect at 1-based [index].
  ///
  /// - PostgreSQL returns `'$1'`, `'$2'`, etc.
  /// - SQLite returns `'?'`.
  String placeholder(int index);

  /// Returns the SQL operator keyword used for case-insensitive string matching.
  ///
  /// - PostgreSQL returns `'ILIKE'`.
  /// - SQLite returns `'LIKE'`.
  String get ilike;

  /// Escapes and quotes an SQL identifier [name] with ANSI double quotes (`"name"`).
  String quoteIdent(String name) => '"$name"';

  /// Wraps an SQL [expr] with an explicit cast to a 64-bit floating point type.
  ///
  /// - PostgreSQL returns `'$expr::float8'`.
  /// - SQLite returns `'CAST($expr AS REAL)'`.
  String castFloat(String expr);

  /// SQL column data type definition for an auto-incrementing integer primary key.
  ///
  /// - PostgreSQL returns `'BIGSERIAL PRIMARY KEY'`.
  /// - SQLite returns `'INTEGER PRIMARY KEY AUTOINCREMENT'`.
  String get autoPkType;

  /// SQL column data type definition for a timezone-aware timestamp.
  ///
  /// - PostgreSQL returns `'TIMESTAMPTZ'`.
  /// - SQLite returns `'TEXT'`.
  String get timestampType;

  /// SQL expression representing the current database server timestamp.
  ///
  /// - PostgreSQL returns `'now()'`.
  /// - SQLite returns `'CURRENT_TIMESTAMP'`.
  String get currentTimestamp;

  /// SQL column data type definition for raw binary data.
  ///
  /// - PostgreSQL returns `'BYTEA'`.
  /// - SQLite returns `'BLOB'`.
  String get byteaType;

  /// Pre-instantiated singleton instance of [PostgresDialect].
  static const Dialect postgres = PostgresDialect();

  /// Pre-instantiated singleton instance of [SqliteDialect].
  static const Dialect sqlite = SqliteDialect();

  /// Infers the appropriate [Dialect] from a database connection [url] string without opening a connection.
  ///
  /// Detects SQLite URLs starting with `sqlite:`, `sqlite3:`, ending with `.db` / `.sqlite`, or matching
  /// `:memory:`. All other URLs default to [Dialect.postgres].
  ///
  /// Example:
  /// ```dart
  /// final d1 = Dialect.fromUrl('sqlite::memory:'); // Dialect.sqlite
  /// final d2 = Dialect.fromUrl('postgres://localhost/db'); // Dialect.postgres
  /// ```
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
///
/// Configures positional placeholders (`$1`, `$2`), `ILIKE` case-insensitive matching,
/// `BIGSERIAL` auto-incrementing keys, and `TIMESTAMPTZ` timestamp types.
///
/// Example:
/// ```dart
/// const dialect = PostgresDialect();
/// assert(dialect.placeholder(3) == r'$3');
/// assert(dialect.ilike == 'ILIKE');
/// ```
class PostgresDialect extends Dialect {
  /// Creates a [PostgresDialect] instance.
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
///
/// Configures anonymous question-mark placeholders (`?`), standard `LIKE` case-insensitive matching,
/// `INTEGER PRIMARY KEY AUTOINCREMENT` keys, and `TEXT` ISO-8601 timestamp types.
///
/// Example:
/// ```dart
/// const dialect = SqliteDialect();
/// assert(dialect.placeholder(1) == '?');
/// assert(dialect.autoPkType == 'INTEGER PRIMARY KEY AUTOINCREMENT');
/// ```
class SqliteDialect extends Dialect {
  /// Creates an [SqliteDialect] instance.
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


