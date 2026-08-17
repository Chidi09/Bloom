// bin/bloom_migrate.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'bloom_migrate',
    'Database migrations CLI for Bloom applications',
  )
    ..addCommand(MakeMigrationsCommand())
    ..addCommand(MigrateCommand())
    ..addCommand(RollbackCommand())
    ..addCommand(StatusCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(64);
  } catch (e, st) {
    stderr.writeln('Error: $e');
    if (Platform.environment['DEBUG'] != null) {
      stderr.writeln(st);
    }
    exit(1);
  }
}

/// Base command providing shared database connection helpers.
abstract class DatabaseCommand extends Command<void> {
  DatabaseCommand() {
    argParser
      ..addOption(
        'url',
        abbr: 'u',
        help: 'Database connection URL (e.g. postgres://user:pass@localhost:5432/dbname or sqlite:app.db)',
        defaultsTo: Platform.environment['DATABASE_URL'] ?? 'sqlite:bloom.db',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Migrations directory path',
        defaultsTo: 'migrations',
      )
      ..addOption(
        'app',
        abbr: 'a',
        help: 'Filter operations to a specific app namespace',
      );
  }

  Future<DbExecutor> openDatabase(String url) async {
    final dialect = Dialect.fromUrl(url);

    if (dialect.type == DialectType.sqlite) {
      String path = url;
      if (path.startsWith('sqlite:')) {
        path = path.substring('sqlite:'.length);
      }
      if (path == ':memory:' || path == '' || path == 'memory') {
        return SqliteDbExecutor.inMemory();
      }
      return SqliteDbExecutor.openFile(path);
    } else {
      return await PostgresDbExecutor.connectUrl(url);
    }
  }
}

/// Generates a new migration file from registered model metadata.
class MakeMigrationsCommand extends Command<void> {
  @override
  final String name = 'makemigrations';

  @override
  final String description =
      'Generates a new numbered .sql migration file for an app.';

  MakeMigrationsCommand() {
    argParser
      ..addFlag(
        'initial',
        help: 'Generate initial schema creation migration for all registered models',
        defaultsTo: true,
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Custom name suffix for the migration (e.g. "initial", "add_tokens")',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Base migrations directory path',
        defaultsTo: 'migrations',
      )
      ..addOption(
        'dialect',
        help: 'Target SQL dialect (postgres or sqlite)',
        allowed: ['postgres', 'sqlite'],
        defaultsTo: 'postgres',
      );
  }

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? [];
    final app = rest.isNotEmpty ? rest.first : 'default';

    final isInitial = argResults?['initial'] as bool? ?? true;
    final customName = argResults?['name'] as String?;
    final dirPath = argResults?['dir'] as String? ?? 'migrations';
    final dialectName = argResults?['dialect'] as String? ?? 'postgres';

    final dialect = dialectName == 'sqlite' ? Dialect.sqlite : Dialect.postgres;

    final models = BloomModelRegistry.instance.getModelsForApp(app);
    if (models.isEmpty) {
      stdout.writeln('No models registered for app "$app".');
      return;
    }

    final targetDir = Directory(p.join(dirPath, app));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // Determine the next migration sequence number
    final existing = targetDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList();

    var nextNumber = 1;
    for (final f in existing) {
      final stem = p.basenameWithoutExtension(f.path);
      final match = RegExp(r'^(\d+)').firstMatch(stem);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n >= nextNumber) {
          nextNumber = n + 1;
        }
      }
    }

    final paddedNumber = nextNumber.toString().padLeft(4, '0');
    final nameSuffix = customName ?? (isInitial ? 'initial' : 'update');
    final fileName = '${paddedNumber}_$nameSuffix.sql';
    final targetFile = File(p.join(targetDir.path, fileName));

    final sqlContent = generateMigrationFileContent(
      models: models,
      dialect: dialect,
    );

    targetFile.writeAsStringSync(sqlContent);
    stdout.writeln('Created migration: ${targetFile.path}');
  }
}

/// Applies pending database migrations.
class MigrateCommand extends DatabaseCommand {
  @override
  final String name = 'migrate';

  @override
  final String description = 'Applies all pending database migrations in sequence.';

  MigrateCommand() {
    argParser.addOption(
      'step',
      abbr: 's',
      help: 'Limit number of migrations to apply',
    );
  }

  @override
  Future<void> run() async {
    final url = argResults?['url'] as String;
    final dir = argResults?['dir'] as String;
    final app = argResults?['app'] as String?;
    final stepStr = argResults?['step'] as String?;
    final limit = stepStr != null ? int.tryParse(stepStr) : null;

    stdout.writeln('Connecting to database...');
    final db = await openDatabase(url);

    try {
      final runner = MigrationRunner(db: db, migrationsDirectory: dir);
      final pending = await runner.getPendingMigrations(app: app);

      if (pending.isEmpty) {
        stdout.writeln('No pending migrations to apply.');
        return;
      }

      stdout.writeln('Applying ${pending.length} pending migration(s)...');

      final applied = await runner.migrate(app: app, limit: limit);
      for (final m in applied) {
        stdout.writeln('  ✓ Applied ${m.app}/${m.name}');
      }
      stdout.writeln('Migration complete. ${applied.length} migration(s) applied.');
    } finally {
      await db.close();
    }
  }
}

/// Rolls back the most recently applied migration(s).
class RollbackCommand extends DatabaseCommand {
  @override
  final String name = 'rollback';

  @override
  final String description = 'Rolls back the most recently applied migration(s).';

  RollbackCommand() {
    argParser.addOption(
      'count',
      abbr: 'c',
      help: 'Number of migrations to roll back',
      defaultsTo: '1',
    );
  }

  @override
  Future<void> run() async {
    final url = argResults?['url'] as String;
    final dir = argResults?['dir'] as String;
    final app = argResults?['app'] as String?;
    final countStr = argResults?['count'] as String? ?? '1';
    final count = int.tryParse(countStr) ?? 1;

    stdout.writeln('Connecting to database...');
    final db = await openDatabase(url);

    try {
      final runner = MigrationRunner(db: db, migrationsDirectory: dir);
      final applied = await runner.getAppliedMigrations(app: app);

      if (applied.isEmpty) {
        stdout.writeln('No applied migrations found to roll back.');
        return;
      }

      stdout.writeln('Rolling back $count migration(s)...');
      final rolledBack = await runner.rollback(app: app, count: count);

      for (final m in rolledBack) {
        stdout.writeln('  ↺ Rolled back ${m.app}/${m.name}');
      }
      stdout.writeln('Rollback complete. ${rolledBack.length} migration(s) undone.');
    } finally {
      await db.close();
    }
  }
}

/// Displays migration status (applied vs pending).
class StatusCommand extends DatabaseCommand {
  @override
  final String name = 'status';

  @override
  final String description = 'Shows applied and pending database migrations.';

  @override
  Future<void> run() async {
    final url = argResults?['url'] as String;
    final dir = argResults?['dir'] as String;
    final app = argResults?['app'] as String?;

    final db = await openDatabase(url);

    try {
      final runner = MigrationRunner(db: db, migrationsDirectory: dir);
      final applied = await runner.getAppliedMigrations(app: app);
      final pending = await runner.getPendingMigrations(app: app);

      stdout.writeln('\n=== Migration Status ===');
      stdout.writeln('Tracking Table: ${MigrationRunner.trackingTableName}\n');

      if (applied.isEmpty && pending.isEmpty) {
        stdout.writeln('No migrations found.');
        return;
      }

      if (applied.isNotEmpty) {
        stdout.writeln('Applied migrations:');
        for (final m in applied) {
          stdout.writeln('  [X] ${m.app}/${m.name} (at ${m.appliedAt.toIso8601String()})');
        }
      }

      if (pending.isNotEmpty) {
        stdout.writeln('\nPending migrations:');
        for (final m in pending) {
          stdout.writeln('  [ ] ${m.app}/${m.name}');
        }
      }
      stdout.writeln();
    } finally {
      await db.close();
    }
  }
}
