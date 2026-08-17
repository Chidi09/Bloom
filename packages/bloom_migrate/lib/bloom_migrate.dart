/// Database migrations CLI and runtime library for Bloom applications built on `bloom_db`.
///
/// Generates dialect-accurate DDL SQL files (`-- up` and `-- down` sections) from `@BloomModel` / [ModelMeta]
/// definitions and provides a transactional migration runner with migration tracking.
///
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
/// import 'package:bloom_migrate/bloom_migrate.dart';
///
/// Future<void> runStartupMigrations(DbExecutor db) async {
///   final runner = MigrationRunner(
///     db: db,
///     migrationsDirectory: 'migrations',
///   );
///   final applied = await runner.migrate();
///   for (final m in applied) {
///     print('Applied startup migration: ${m.app}/${m.name}');
///   }
/// }
/// ```
library bloom_migrate;

export 'src/errors.dart';
export 'src/migration_file.dart';
export 'src/migration_runner.dart';
export 'src/model_registry.dart';
export 'src/schema_sql.dart';
