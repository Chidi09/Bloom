// lib/src/migration_file.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'errors.dart';

/// Represents a single parsed database migration file following the
/// `migrations/<app>/NNNN_name.sql` convention with `-- up` and `-- down` sections.
///
/// Encapsulates the migration metadata (application namespace, sequence number, file stem)
/// and SQL blocks for forward execution and backward rollback.
///
/// Example:
/// ```dart
/// final migration = BloomMigration.parse(
///   app: 'accounts',
///   name: '0001_initial',
///   filePath: 'migrations/accounts/0001_initial.sql',
///   content: '''
/// -- up
/// CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT);
///
/// -- down
/// DROP TABLE users;
/// ''',
/// );
///
/// print(migration.number); // 1
/// print(migration.hasDown); // true
/// print(migration.upStatements); // ['CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT);']
/// ```
class BloomMigration implements Comparable<BloomMigration> {
  /// The logical app or domain name (e.g. `accounts`, `billing`).
  final String app;

  /// The migration name identifier (file stem, e.g. `0001_accounts`).
  final String name;

  /// The sequence number parsed from the file prefix (e.g. 1 from `0001_accounts.sql`).
  final int number;

  /// The absolute or relative file path to the migration file on disk.
  final String filePath;

  /// The raw SQL content of the `-- up` section.
  final String upSql;

  /// The raw SQL content of the `-- down` section (empty if not specified or `-- no-down`).
  final String downSql;

  /// Whether this migration has a reversible `-- down` migration defined.
  ///
  /// Returns `true` if [downSql] contains non-whitespace SQL statements; otherwise `false`.
  bool get hasDown => downSql.trim().isNotEmpty;

  /// Creates a [BloomMigration] descriptor with explicit attributes and SQL sections.
  const BloomMigration({
    required this.app,
    required this.name,
    required this.number,
    required this.filePath,
    required this.upSql,
    required this.downSql,
  });

  /// Parses a [BloomMigration] from raw file [content].
  ///
  /// Extracts the leading integer sequence number from [name]. Parses `-- up`,
  /// `-- down`, and `-- no-down` markers in [content]. If `-- no-down` is present,
  /// [downSql] will be empty and [hasDown] will evaluate to `false`.
  ///
  /// Example:
  /// ```dart
  /// final migration = BloomMigration.parse(
  ///   app: 'billing',
  ///   name: '0002_add_invoices',
  ///   filePath: 'migrations/billing/0002_add_invoices.sql',
  ///   content: fileText,
  /// );
  /// ```
  factory BloomMigration.parse({
    required String app,
    required String name,
    required String filePath,
    required String content,
  }) {
    final number = _parseMigrationNumber(name);

    if (content.contains('-- no-down')) {
      final upSection = _extractSection(content, 'up');
      return BloomMigration(
        app: app,
        name: name,
        number: number,
        filePath: filePath,
        upSql: upSection.trim(),
        downSql: '',
      );
    }

    final upSection = _extractSection(content, 'up');
    final downSection = _extractSection(content, 'down');

    return BloomMigration(
      app: app,
      name: name,
      number: number,
      filePath: filePath,
      upSql: upSection.trim(),
      downSql: downSection.trim(),
    );
  }

  /// Loads and parses a migration from a local [file] on disk.
  ///
  /// If [app] is omitted, the application namespace is inferred from the parent
  /// directory name of [file].
  ///
  /// Throws a [MigrationFileNotFoundException] if [file] does not exist.
  ///
  /// Example:
  /// ```dart
  /// final file = File('migrations/auth/0001_auth_tables.sql');
  /// final migration = BloomMigration.fromFile(file);
  /// print(migration.app); // 'auth'
  /// ```
  factory BloomMigration.fromFile(File file, {String? app}) {
    if (!file.existsSync()) {
      throw MigrationFileNotFoundException(file.path);
    }

    final content = file.readAsStringSync();
    final fileName = p.basename(file.path);
    final name = p.basenameWithoutExtension(fileName);

    // If app is not provided, infer from parent directory name
    final inferredApp = app ?? p.basename(file.parent.path);

    return BloomMigration.parse(
      app: inferredApp,
      name: name,
      filePath: file.path,
      content: content,
    );
  }

  /// Parses the individual SQL statements from the `-- up` block.
  ///
  /// Uses [splitSqlStatements] to segment statements by semicolon while ignoring comments and strings.
  List<String> get upStatements => splitSqlStatements(upSql);

  /// Parses the individual SQL statements from the `-- down` block.
  ///
  /// Uses [splitSqlStatements] to segment statements by semicolon while ignoring comments and strings.
  List<String> get downStatements => splitSqlStatements(downSql);

  /// Formats `-- up` and `-- down` SQL sections into standard migration file text.
  ///
  /// When [noDown] is `true` or [downSql] is null/empty, the output includes `-- no-down`.
  /// Otherwise, it outputs `-- up` followed by the up SQL, and `-- down` followed by the down SQL.
  ///
  /// Example:
  /// ```dart
  /// final fileText = BloomMigration.format(
  ///   upSql: 'CREATE TABLE logs (id INTEGER PRIMARY KEY);',
  ///   downSql: 'DROP TABLE logs;',
  /// );
  /// ```
  static String format({
    required String upSql,
    String? downSql,
    bool noDown = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('-- up');
    buffer.writeln(upSql.trim());
    buffer.writeln();

    if (noDown || (downSql == null || downSql.trim().isEmpty)) {
      buffer.writeln('-- no-down');
    } else {
      buffer.writeln('-- down');
      buffer.writeln(downSql.trim());
    }

    return buffer.toString();
  }

  @override
  int compareTo(BloomMigration other) {
    if (app != other.app) {
      return app.compareTo(other.app);
    }
    if (number != other.number) {
      return number.compareTo(other.number);
    }
    return name.compareTo(other.name);
  }

  @override
  String toString() => 'BloomMigration($app/$name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomMigration &&
          runtimeType == other.runtimeType &&
          app == other.app &&
          name == other.name;

  @override
  int get hashCode => Object.hash(app, name);

  static int _parseMigrationNumber(String stem) {
    final match = RegExp(r'^(\d+)').firstMatch(stem);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  static String _extractSection(String text, String wanted) {
    final lines = text.split('\n');
    String? currentSection;
    final sectionLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '-- up') {
        currentSection = 'up';
        continue;
      } else if (trimmed == '-- down') {
        currentSection = 'down';
        continue;
      } else if (trimmed == '-- no-down') {
        currentSection = 'no-down';
        continue;
      }

      if (currentSection == wanted) {
        sectionLines.add(line);
      }
    }

    return sectionLines.join('\n');
  }
}

/// Splits a raw SQL block into executable statements, properly handling semicolons
/// and ignoring comments and string literals.
///
/// Recognizes line comments, nested block comments, quoted strings, and PostgreSQL
/// dollar-quoted literals. Empty statements are excluded.
///
/// Example:
/// ```dart
/// final sql = '''
/// -- Create users
/// CREATE TABLE users (id INT, name TEXT);
/// INSERT INTO users VALUES (1, 'O''Reilly; author');
/// ''';
/// final statements = splitSqlStatements(sql);
/// print(statements.length); // 2
/// ```
List<String> splitSqlStatements(String sql) {
  if (sql.trim().isEmpty) return [];

  final statements = <String>[];
  final buffer = StringBuffer();
  String? quote;
  String? dollarQuote;
  var lineComment = false;
  var blockCommentDepth = 0;

  for (var i = 0; i < sql.length; i++) {
    final char = sql[i];
    final next = i + 1 < sql.length ? sql[i + 1] : '';

    if (lineComment) {
      buffer.write(char);
      if (char == '\n') lineComment = false;
      continue;
    }
    if (blockCommentDepth > 0) {
      buffer.write(char);
      if (char == '/' && next == '*') {
        buffer.write(next);
        i++;
        blockCommentDepth++;
      } else if (char == '*' && next == '/') {
        buffer.write(next);
        i++;
        blockCommentDepth--;
      }
      continue;
    }
    if (dollarQuote != null) {
      if (sql.startsWith(dollarQuote, i)) {
        buffer.write(dollarQuote);
        i += dollarQuote.length - 1;
        dollarQuote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }
    if (quote != null) {
      buffer.write(char);
      if (char == quote) {
        if (next == quote) {
          buffer.write(next);
          i++;
        } else {
          quote = null;
        }
      }
      continue;
    }

    if (char == '-' && next == '-') {
      buffer.write(char);
      buffer.write(next);
      i++;
      lineComment = true;
    } else if (char == '/' && next == '*') {
      buffer.write(char);
      buffer.write(next);
      i++;
      blockCommentDepth = 1;
    } else if (char == "'" || char == '"') {
      quote = char;
      buffer.write(char);
    } else if (char == r'$') {
      final match = RegExp(r'^\$[A-Za-z_][A-Za-z0-9_]*\$|^\$\$')
          .matchAsPrefix(sql.substring(i));
      if (match != null) {
        dollarQuote = match.group(0)!;
        buffer.write(dollarQuote);
        i += dollarQuote.length - 1;
      } else {
        buffer.write(char);
      }
    } else if (char == ';') {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) statements.add('$statement;');
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    statements.add(remaining.endsWith(';') ? remaining : '$remaining;');
  }

  return statements;
}
