/// Database migrations runtime and schema generation library for Bloom applications.
///
/// The `bloom_migrate` package provides transactional database migration capabilities,
/// schema diffing and SQL generation from `bloom_db` models, automated migration file
/// parsing, and migration rollback support.
///
/// ### Overview
/// - **Schema Generation**: Converts [ModelMeta] entity descriptors into dialect-accurate
///   DDL statements (PostgreSQL, SQLite) including tables, constraints, foreign keys,
///   many-to-many join tables, and indexes using [generateMigrationFileContent] or [generateCreateTableSql].
/// - **Topological Sorting**: Resolves foreign key dependency graphs automatically using
///   [sortModelsTopologically] to ensure parent tables are created before child tables and
///   dropped in reverse order.
/// - **File Conventions**: Parses and formats SQL migration files following the standard
///   `migrations/<app>/NNNN_name.sql` pattern with `-- up` and `-- down` (or `-- no-down`) blocks.
/// - **Transactional Runner**: [MigrationRunner] manages the `bloom_migrations` tracking table,
///   discovers pending migrations on disk, and applies or rolls them back inside isolated database transactions.
///
/// ### Running Migrations
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
/// import 'package:bloom_migrate/bloom_migrate.dart';
///
/// Future<void> runStartupMigrations(DbExecutor db) async {
///   final runner = MigrationRunner(
///     db: db,
///     migrationsDirectory: 'migrations',
///   );
///
///   final pending = await runner.getPendingMigrations();
///   print('Pending migrations: ${pending.length}');
///
///   final applied = await runner.migrate();
///   for (final record in applied) {
///     print('Applied: ${record.app}/${record.name} at ${record.appliedAt}');
///   }
/// }
/// ```
///
/// ### Generating SQL from Models
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
/// import 'package:bloom_migrate/bloom_migrate.dart';
///
/// void generateSql(List<ModelMeta> models, Dialect dialect) {
///   final sql = generateMigrationFileContent(
///     models: models,
///     dialect: dialect,
///   );
///   print(sql);
/// }
/// ```
library bloom_migrate;

export 'src/errors.dart';
export 'src/migration_file.dart';
export 'src/migration_runner.dart';
export 'src/model_registry.dart';
export 'src/schema_sql.dart';
