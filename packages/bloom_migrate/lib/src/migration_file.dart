// lib/src/migration_file.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'errors.dart';

/// Represents a single parsed database migration file following the
/// `migrations/<app>/NNNN_name.sql` convention with `-- up` and `-- down` sections.
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
  bool get hasDown => downSql.trim().isNotEmpty;

  const BloomMigration({
    required this.app,
    required this.name,
    required this.number,
    required this.filePath,
    required this.upSql,
    required this.downSql,
  });

  /// Parses a [BloomMigration] from raw file content.
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

  /// Loads and parses a migration from a local file on disk.
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
  List<String> get upStatements => splitSqlStatements(upSql);

  /// Parses the individual SQL statements from the `-- down` block.
  List<String> get downStatements => splitSqlStatements(downSql);

  /// Formats `-- up` and `-- down` SQL sections into standard migration file text.
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
List<String> splitSqlStatements(String sql) {
  if (sql.trim().isEmpty) return [];

  final statements = <String>[];
  final buffer = StringBuffer();
  var inString = false;
  var stringChar = '';

  final lines = sql.split('\n');
  for (final rawLine in lines) {
    final line = rawLine.trim();
    // Skip full comment lines
    if (line.startsWith('--')) continue;

    for (var i = 0; i < rawLine.length; i++) {
      final char = rawLine[i];

      if (inString) {
        buffer.write(char);
        if (char == stringChar) {
          // Check for escaped quote (e.g. '')
          if (i + 1 < rawLine.length && rawLine[i + 1] == stringChar) {
            buffer.write(rawLine[i + 1]);
            i++;
          } else {
            inString = false;
          }
        }
      } else {
        if (char == "'" || char == '"') {
          inString = true;
          stringChar = char;
          buffer.write(char);
        } else if (char == '-' && i + 1 < rawLine.length && rawLine[i + 1] == '-') {
          // Rest of line is comment
          break;
        } else if (char == ';') {
          final stmt = buffer.toString().trim();
          if (stmt.isNotEmpty) {
            statements.add('$stmt;');
          }
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    buffer.write('\n');
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    statements.add(remaining.endsWith(';') ? remaining : '$remaining;');
  }

  return statements;
}
