// lib/src/errors.dart

/// Base class for all migration-related errors in Bloom.
abstract class MigrationException implements Exception {
  final String message;
  const MigrationException(this.message);

  @override
  String toString() => 'MigrationException: $message';
}

/// Thrown when a migration file cannot be found or read from disk.
class MigrationFileNotFoundException extends MigrationException {
  final String path;
  const MigrationFileNotFoundException(this.path)
      : super('Migration file not found at: $path');
}

/// Thrown when attempting to roll back a migration that has no `-- down` section
/// or has explicitly opted out of reversal with `-- no-down`.
class MigrationNonInvertibleException extends MigrationException {
  final String migrationName;
  const MigrationNonInvertibleException(this.migrationName)
      : super(
            'Migration "$migrationName" has no down SQL and cannot be rolled back.');
}

/// Thrown when models have a circular foreign key dependency preventing
/// clean topological ordering for table creation.
class MigrationCyclicDependencyException extends MigrationException {
  final List<String> models;
  MigrationCyclicDependencyException(this.models)
      : super('Cyclic dependency detected between models: ${models.join(", ")}');
}

/// Thrown when a SQL DDL statement execution fails during a migration.
class MigrationExecutionException extends MigrationException {
  final String migrationName;
  final String sql;
  final Object cause;
  final StackTrace? stackTrace;

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
class MissingMaxLengthException extends MigrationException {
  final String modelName;
  final String fieldName;
  const MissingMaxLengthException({
    required this.modelName,
    required this.fieldName,
  }) : super(
            'Field "$fieldName" in model "$modelName" requires a max_length specification.');
}

/// Thrown when an operation is not supported by the target SQL dialect.
class UnsupportedDialectOperationException extends MigrationException {
  final String operation;
  final String dialect;
  const UnsupportedDialectOperationException({
    required this.operation,
    required this.dialect,
  }) : super('Operation "$operation" is not supported on dialect "$dialect".');
}
