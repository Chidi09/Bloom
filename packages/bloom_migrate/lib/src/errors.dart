// lib/src/errors.dart

/// Base class for all migration-related errors in Bloom.
///
/// Subclasses represent specific failure modes during migration file discovery,
/// SQL generation, model dependency resolution, or transactional SQL execution.
abstract class MigrationException implements Exception {
  /// A human-readable description of the migration error.
  final String message;

  /// Creates a [MigrationException] with the specified [message].
  const MigrationException(this.message);

  @override
  String toString() => 'MigrationException: $message';
}

/// Thrown when a migration file cannot be found or read from disk.
///
/// Typically thrown during rollback or discovery when a recorded migration
/// has no matching `.sql` file in the configured migrations directory.
///
/// Example:
/// ```dart
/// throw MigrationFileNotFoundException('migrations/accounts/0001_initial.sql');
/// ```
class MigrationFileNotFoundException extends MigrationException {
  /// The file path on disk that could not be located.
  final String path;

  /// Creates a [MigrationFileNotFoundException] for the missing file at [path].
  const MigrationFileNotFoundException(this.path)
      : super('Migration file not found at: $path');
}

/// Thrown when attempting to roll back a migration that has no `-- down` section
/// or has explicitly opted out of reversal with `-- no-down`.
///
/// Example:
/// ```dart
/// if (!migration.hasDown) {
///   throw MigrationNonInvertibleException('accounts/0002_drop_legacy');
/// }
/// ```
class MigrationNonInvertibleException extends MigrationException {
  /// The identifier of the migration that cannot be inverted (e.g. `accounts/0002_data_migration`).
  final String migrationName;

  /// Creates a [MigrationNonInvertibleException] for [migrationName].
  const MigrationNonInvertibleException(this.migrationName)
      : super(
            'Migration "$migrationName" has no down SQL and cannot be rolled back.');
}

/// Thrown when models have a circular foreign key dependency preventing
/// clean topological ordering for table creation.
///
/// Example:
/// ```dart
/// // If Model A depends on Model B, and Model B depends on Model A
/// throw MigrationCyclicDependencyException(['User', 'Profile']);
/// ```
class MigrationCyclicDependencyException extends MigrationException {
  /// The names of the models participating in the dependency cycle.
  final List<String> models;

  /// Creates a [MigrationCyclicDependencyException] listing the cycle's [models].
  MigrationCyclicDependencyException(this.models)
      : super('Cyclic dependency detected between models: ${models.join(", ")}');
}

/// Thrown when a SQL DDL statement execution fails during a migration.
///
/// Captures the failed [sql] statement, the underlying [cause], and the [migrationName]
/// so that failed transactions can report actionable error details.
///
/// Example:
/// ```dart
/// try {
///   await db.execute(stmt);
/// } catch (e, st) {
///   throw MigrationExecutionException(
///     migrationName: 'accounts/0001_initial',
///     sql: stmt,
///     cause: e,
///     stackTrace: st,
///   );
/// }
/// ```
class MigrationExecutionException extends MigrationException {
  /// The identifier of the migration where execution failed (e.g. `accounts/0001_initial`).
  final String migrationName;

  /// The raw SQL statement or block that caused the execution failure.
  final String sql;

  /// The underlying database error or exception thrown by the driver.
  final Object cause;

  /// The optional stack trace associated with the original [cause].
  final StackTrace? stackTrace;

  /// Creates a [MigrationExecutionException] capturing the failed [migrationName], [sql], [cause], and optional [stackTrace].
  MigrationExecutionException({
    required this.migrationName,
    required this.sql,
    required this.cause,
    this.stackTrace,
  }) : super('Failed executing migration "$migrationName": $cause\nSQL: $sql');

  @override
  String toString() =>
      'MigrationExecutionException: Failed executing migration "$migrationName": $cause\nSQL: $sql';
}

/// Thrown when a field with a character kind is missing a required `max_length` attribute on PostgreSQL.
///
/// Example:
/// ```dart
/// throw MissingMaxLengthException(
///   modelName: 'User',
///   fieldName: 'username',
/// );
/// ```
class MissingMaxLengthException extends MigrationException {
  /// The name of the model containing the invalid field definition.
  final String modelName;

  /// The name of the field that is missing a max length specification.
  final String fieldName;

  /// Creates a [MissingMaxLengthException] for [fieldName] on [modelName].
  const MissingMaxLengthException({
    required this.modelName,
    required this.fieldName,
  }) : super(
            'Field "$fieldName" in model "$modelName" requires a max_length specification.');
}

/// Thrown when an operation is not supported by the target SQL dialect.
///
/// Example:
/// ```dart
/// throw UnsupportedDialectOperationException(
///   operation: 'ALTER COLUMN TYPE',
///   dialect: 'sqlite',
/// );
/// ```
class UnsupportedDialectOperationException extends MigrationException {
  /// The name or description of the unsupported operation.
  final String operation;

  /// The target database dialect name (e.g. `sqlite`, `postgres`).
  final String dialect;

  /// Creates an [UnsupportedDialectOperationException] for [operation] on [dialect].
  const UnsupportedDialectOperationException({
    required this.operation,
    required this.dialect,
  }) : super('Operation "$operation" is not supported on dialect "$dialect".');
}
