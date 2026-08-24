// lib/src/migration_runner.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:bloom_db/bloom_db.dart';
import 'errors.dart';
import 'migration_file.dart';

/// Represents a migration record stored in the `bloom_migrations` tracking table.
///
/// Records which migration file was applied, its application namespace, and the UTC timestamp
/// of its execution.
///
/// Example:
/// ```dart
/// final applied = await runner.getAppliedMigrations();
/// for (final record in applied) {
///   print('Migration #${record.id}: ${record.app}/${record.name} on ${record.appliedAt}');
/// }
/// ```
class AppliedMigration {
  /// The auto-increment primary key ID in the tracking table.
  final int id;

  /// The application namespace (e.g. `accounts`).
  final String app;

  /// The migration name (e.g. `0001_accounts`).
  final String name;

  /// The timestamp when this migration was executed.
  final DateTime appliedAt;

  /// Creates an [AppliedMigration] descriptor.
  const AppliedMigration({
    required this.id,
    required this.app,
    required this.name,
    required this.appliedAt,
  });

  @override
  String toString() => 'AppliedMigration(id: $id, app: $app, name: $name, appliedAt: $appliedAt)';
}

/// The database migration engine for Bloom applications.
///
/// [MigrationRunner] handles discovery of `.sql` migration files on disk,
/// tracks execution state in the `bloom_migrations` database table, and executes
/// forward migrations or rollbacks inside transactional boundaries (`BEGIN` / `COMMIT` / `ROLLBACK`).
///
/// Example:
/// ```dart
/// final runner = MigrationRunner(
///   db: dbExecutor,
///   migrationsDirectory: 'migrations',
/// );
///
/// // Check pending migrations
/// final pending = await runner.getPendingMigrations();
/// print('Found ${pending.length} pending migrations.');
///
/// // Run forward migrations
/// final applied = await runner.migrate();
///
/// // Roll back the last migration if needed
/// await runner.rollback(count: 1);
/// ```
class MigrationRunner {
  /// The database executor connected to the target database.
  final DbExecutor db;

  /// The base directory path where migrations are stored (defaults to `migrations`).
  final String migrationsDirectory;

  /// The name of the database table used to track executed migrations.
  static const String trackingTableName = 'bloom_migrations';

  /// Creates a [MigrationRunner] bound to the given [db] executor and optional [migrationsDirectory].
  MigrationRunner({
    required this.db,
    this.migrationsDirectory = 'migrations',
  });

  /// Ensures that the migration history tracking table `bloom_migrations` exists in the database.
  ///
  /// Automatically adjusts primary key, text, and timestamp column types according to the active [db] dialect.
  /// Safe to call multiple times (`CREATE TABLE IF NOT EXISTS`).
  ///
  /// Example:
  /// ```dart
  /// await runner.ensureTrackingTable();
  /// ```
  Future<void> ensureTrackingTable() async {
    final dialect = db.dialect;
    final isPostgres = dialect.type == DialectType.postgres;

    final idType = dialect.autoPkType;
    final textType = isPostgres ? 'VARCHAR(255)' : 'TEXT';
    final timestampType = dialect.timestampType;
    final currentTs = dialect.currentTimestamp;

    final sql = '''CREATE TABLE IF NOT EXISTS $trackingTableName (
    id $idType,
    app $textType NOT NULL,
    name $textType NOT NULL,
    applied_at $timestampType NOT NULL DEFAULT $currentTs,
    CONSTRAINT uniq_${trackingTableName}_app_name UNIQUE (app, name)
);''';

    await db.execute(sql);
  }

  /// Fetches all applied migration records from the tracking table, ordered by ID ascending.
  ///
  /// When [app] is provided, only migrations matching that application namespace are returned.
  ///
  /// Example:
  /// ```dart
  /// final applied = await runner.getAppliedMigrations(app: 'auth');
  /// ```
  Future<List<AppliedMigration>> getAppliedMigrations({String? app}) async {
    await ensureTrackingTable();
    final dialect = db.dialect;

    String sql = 'SELECT id, app, name, applied_at FROM $trackingTableName';
    final params = <dynamic>[];

    if (app != null) {
      sql += ' WHERE app = ${dialect.placeholder(1)}';
      params.add(app);
    }

    sql += ' ORDER BY id ASC';

    final rows = await db.fetchAll(sql, params);
    return rows.map((row) {
      final id = row.tryIntByName('id') ?? row.tryInt(0) ?? 0;
      final appName = row.tryStringByName('app') ?? row.tryString(1) ?? '';
      final migName = row.tryStringByName('name') ?? row.tryString(2) ?? '';
      final appliedAt = row.tryDateTimeByName('applied_at') ??
          row.tryDateTime(3) ??
          DateTime.now().toUtc();

      return AppliedMigration(
        id: id,
        app: appName,
        name: migName,
        appliedAt: appliedAt,
      );
    }).toList();
  }

  /// Discovers all `.sql` migration files in the configured [migrationsDirectory] tree.
  ///
  /// Automatically discovers files formatted as `migrations/<app>/NNNN_name.sql`
  /// or directly inside `migrations/NNNN_name.sql`. Returns discovered migrations sorted
  /// by app name, sequence number, and file stem.
  ///
  /// When [app] is provided, only migrations for that application are returned.
  ///
  /// Example:
  /// ```dart
  /// final migrations = runner.discoverMigrations();
  /// for (final m in migrations) {
  ///   print('${m.app}/${m.name} (#${m.number})');
  /// }
  /// ```
  List<BloomMigration> discoverMigrations({String? app}) {
    final baseDir = Directory(migrationsDirectory);
    if (!baseDir.existsSync()) {
      return [];
    }

    final migrations = <BloomMigration>[];

    // Check if the directory itself contains NNNN_*.sql files directly
    final directSqlFiles = baseDir
        .listSync()
        .whereType<File>()
        .where((f) => _isMigrationFile(p.basename(f.path)))
        .toList();

    if (directSqlFiles.isNotEmpty) {
      for (final file in directSqlFiles) {
        final mig = BloomMigration.fromFile(file, app: app ?? 'default');
        if (app == null || mig.app == app) {
          migrations.add(mig);
        }
      }
    }

    // Also scan all subdirectories (representing apps e.g. migrations/accounts/)
    final subDirs = baseDir.listSync().whereType<Directory>().toList();
    for (final dir in subDirs) {
      final appName = p.basename(dir.path);
      if (app != null && appName != app) {
        continue;
      }

      final appFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => _isMigrationFile(p.basename(f.path)))
          .toList();

      for (final file in appFiles) {
        migrations.add(BloomMigration.fromFile(file, app: appName));
      }
    }

    migrations.sort();
    return migrations;
  }

  /// Returns all discovered migrations that have not yet been applied to the database.
  ///
  /// Compares local files found via [discoverMigrations] with database records
  /// retrieved from [getAppliedMigrations]. When [app] is provided, limits check to that app.
  ///
  /// Example:
  /// ```dart
  /// final pending = await runner.getPendingMigrations();
  /// if (pending.isNotEmpty) {
  ///   print('Need to apply ${pending.length} migrations.');
  /// }
  /// ```
  Future<List<BloomMigration>> getPendingMigrations({String? app}) async {
    final applied = await getAppliedMigrations(app: app);
    final appliedSet = {for (final m in applied) '${m.app}:${m.name}'};

    final allDiscovered = discoverMigrations(app: app);
    return allDiscovered
        .where((m) => !appliedSet.contains('${m.app}:${m.name}'))
        .toList();
  }

  /// Applies a single [migration] file in a dedicated database transaction.
  ///
  /// Executes each SQL statement in [BloomMigration.upStatements] sequentially inside `BEGIN` ... `COMMIT`.
  /// Upon successful completion, inserts a record into [trackingTableName].
  ///
  /// If any statement fails, rolls back the transaction and throws a [MigrationExecutionException].
  ///
  /// Example:
  /// ```dart
  /// final migration = runner.discoverMigrations().first;
  /// final record = await runner.applyMigration(migration);
  /// print('Applied at ${record.appliedAt}');
  /// ```
  Future<AppliedMigration> applyMigration(BloomMigration migration) async {
    await ensureTrackingTable();
    final dialect = db.dialect;

    // Begin transaction
    await db.execute('BEGIN');

    try {
      // Execute each up statement in sequence
      for (final stmt in migration.upStatements) {
        final cleanStmt = stmt.trim();
        if (cleanStmt.isNotEmpty) {
          await db.execute(cleanStmt);
        }
      }

      // Record in tracking table
      final insertSql = '''INSERT INTO $trackingTableName (app, name)
VALUES (${dialect.placeholder(1)}, ${dialect.placeholder(2)})''';

      await db.execute(insertSql, [migration.app, migration.name]);

      await db.execute('COMMIT');

      return AppliedMigration(
        id: 0,
        app: migration.app,
        name: migration.name,
        appliedAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      try {
        await db.execute('ROLLBACK');
      } catch (_) {}

      throw MigrationExecutionException(
        migrationName: '${migration.app}/${migration.name}',
        sql: migration.upSql,
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Applies all pending migrations in chronological order.
  ///
  /// If [app] is specified, only pending migrations for that application are applied.
  /// If [limit] is provided, applies at most [limit] pending migrations.
  /// Returns the list of newly [AppliedMigration] records.
  ///
  /// Example:
  /// ```dart
  /// // Apply at most 2 pending migrations for the 'billing' app
  /// final applied = await runner.migrate(app: 'billing', limit: 2);
  /// ```
  Future<List<AppliedMigration>> migrate({
    String? app,
    int? limit,
  }) async {
    final pending = await getPendingMigrations(app: app);
    if (pending.isEmpty) {
      return [];
    }

    final toApply = limit != null ? pending.take(limit).toList() : pending;
    final results = <AppliedMigration>[];

    for (final mig in toApply) {
      final applied = await applyMigration(mig);
      results.add(applied);
    }

    return results;
  }

  /// Rolls back a single applied [migration] using its `-- down` section within a transaction.
  ///
  /// Executes each SQL statement in [BloomMigration.downStatements] sequentially inside `BEGIN` ... `COMMIT`
  /// and removes the corresponding row from [trackingTableName].
  ///
  /// Throws a [MigrationNonInvertibleException] if [migration] does not define a down SQL section.
  /// Throws a [MigrationExecutionException] if statement execution fails.
  ///
  /// Example:
  /// ```dart
  /// final reverted = await runner.rollbackMigration(lastMigration);
  /// print('Reverted: ${reverted.name}');
  /// ```
  Future<BloomMigration> rollbackMigration(BloomMigration migration) async {
    if (!migration.hasDown) {
      throw MigrationNonInvertibleException('${migration.app}/${migration.name}');
    }

    await ensureTrackingTable();
    final dialect = db.dialect;

    await db.execute('BEGIN');

    try {
      // Execute down statements in sequence
      for (final stmt in migration.downStatements) {
        final cleanStmt = stmt.trim();
        if (cleanStmt.isNotEmpty) {
          await db.execute(cleanStmt);
        }
      }

      // Remove from tracking table
      final deleteSql = '''DELETE FROM $trackingTableName
WHERE app = ${dialect.placeholder(1)} AND name = ${dialect.placeholder(2)}''';

      await db.execute(deleteSql, [migration.app, migration.name]);

      await db.execute('COMMIT');
      return migration;
    } catch (e, st) {
      try {
        await db.execute('ROLLBACK');
      } catch (_) {}

      throw MigrationExecutionException(
        migrationName: '${migration.app}/${migration.name}',
        sql: migration.downSql,
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Rolls back the most recent [count] applied migrations.
  ///
  /// Lookups applied migration history, locates the corresponding migration file on disk,
  /// and invokes [rollbackMigration] in reverse order.
  ///
  /// When [app] is specified, only migrations for that app are rolled back.
  /// Returns the list of rolled-back [BloomMigration] descriptors.
  ///
  /// Throws a [MigrationFileNotFoundException] if the disk migration file corresponding
  /// to an applied record cannot be found.
  ///
  /// Example:
  /// ```dart
  /// final rolledBack = await runner.rollback(count: 2);
  /// for (final m in rolledBack) {
  ///   print('Rolled back: ${m.app}/${m.name}');
  /// }
  /// ```
  Future<List<BloomMigration>> rollback({
    String? app,
    int count = 1,
  }) async {
    if (count <= 0) return [];

    final applied = await getAppliedMigrations(app: app);
    if (applied.isEmpty) {
      return [];
    }

    final allDiscovered = discoverMigrations(app: app);
    final migrationMap = {
      for (final m in allDiscovered) '${m.app}:${m.name}': m,
    };

    // Take the most recently applied migrations (end of the list)
    final toRollback = applied.reversed.take(count).toList();
    final results = <BloomMigration>[];

    for (final record in toRollback) {
      final key = '${record.app}:${record.name}';
      final migration = migrationMap[key];

      if (migration == null) {
        throw MigrationFileNotFoundException(
          'Could not find local migration file for applied migration $key',
        );
      }

      await rollbackMigration(migration);
      results.add(migration);
    }

    return results;
  }

  static bool _isMigrationFile(String fileName) {
    if (!fileName.endsWith('.sql')) return false;
    final stem = p.basenameWithoutExtension(fileName);
    return RegExp(r'^\d{4}_').hasMatch(stem);
  }
}
