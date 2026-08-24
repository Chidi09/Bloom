// lib/src/errors.dart

/// Base exception class for all errors and exceptions raised by Bloom ORM operations.
///
/// Subclasses represent specific database query errors, metadata validation failures,
/// or dialect incompatibilities.
///
/// Example:
/// ```dart
/// try {
///   final user = await QuerySet<User>(meta: User.meta, fromRow: User.fromRow)
///       .filter({'id': 999})
///       .get(db);
/// } on BloomOrmException catch (e) {
///   print('ORM error occurred: ${e.message}');
/// }
/// ```
abstract class BloomOrmException implements Exception {
  /// The detailed diagnostic error message.
  final String message;

  /// Creates a [BloomOrmException] with the given [message].
  const BloomOrmException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when a single-object query (such as `QuerySet.get()` or `DbExecutor.fetchOne()`)
/// finds zero matching database records.
///
/// Mirrors `OrmError::NotFound`.
///
/// Example:
/// ```dart
/// try {
///   final user = await queryset.get(db);
/// } on BloomOrmNotFoundError catch (e) {
///   print('No record found for model ${e.model}');
/// }
/// ```
class BloomOrmNotFoundError extends BloomOrmException {
  /// The struct/class name of the target model that was not found.
  final String model;

  /// Creates an error indicating that no matching [model] record was found in the database.
  BloomOrmNotFoundError({required this.model})
      : super('Model $model not found');
}

/// Exception thrown when a single-object query (`QuerySet.get()`) matches more than one record.
///
/// Mirrors `OrmError::MultipleObjectsReturned`.
///
/// Example:
/// ```dart
/// try {
///   final user = await queryset.filter({'role': 'admin'}).get(db);
/// } on BloomOrmMultipleObjectsReturnedError catch (e) {
///   print('Expected 1 record but found multiple for ${e.model}');
/// }
/// ```
class BloomOrmMultipleObjectsReturnedError extends BloomOrmException {
  /// The struct/class name of the target model.
  final String model;

  /// Creates an error indicating that multiple [model] records matched a single-object query.
  BloomOrmMultipleObjectsReturnedError({required this.model})
      : super('Multiple $model objects returned');
}

/// Exception thrown when a queryset is configured in an invalid state that cannot generate valid SQL.
///
/// Mirrors `OrmError::InvalidQuery`.
///
/// Example:
/// ```dart
/// try {
///   await queryset.values(db, []); // empty fields list is invalid
/// } on BloomOrmInvalidQueryError catch (e) {
///   print('Invalid query structure: ${e.message}');
/// }
/// ```
class BloomOrmInvalidQueryError extends BloomOrmException {
  /// Creates an error indicating invalid query configuration with the given diagnostic [message].
  BloomOrmInvalidQueryError(String message) : super('Invalid query: $message');
}

/// Exception thrown when referencing a field or column name that does not exist in model metadata.
///
/// Mirrors `OrmError::FieldNotFound`.
///
/// Example:
/// ```dart
/// try {
///   await queryset.filter({'non_existent_column': 123}).all(db);
/// } on BloomOrmFieldNotFoundError catch (e) {
///   print('Field ${e.field} is missing from model ${e.model}');
/// }
/// ```
class BloomOrmFieldNotFoundError extends BloomOrmException {
  /// The name of the missing field or column lookup.
  final String field;

  /// The name of the target model missing the field.
  final String model;

  /// Creates an error indicating that [field] does not exist on [model].
  BloomOrmFieldNotFoundError({required this.field, required this.model})
      : super('Field $field not found on model $model');
}

/// Exception thrown when attempting an operation not supported by the active database dialect.
///
/// Mirrors `OrmError::UnsupportedOnDialect`.
///
/// Example:
/// ```dart
/// try {
///   // Some Postgres-only feature executed on SQLite
///   throw BloomOrmUnsupportedOnDialectError('Array aggregates require PostgreSQL');
/// } on BloomOrmUnsupportedOnDialectError catch (e) {
///   print(e.message);
/// }
/// ```
class BloomOrmUnsupportedOnDialectError extends BloomOrmException {
  /// Creates an error indicating that an operation is unsupported on the current dialect with [message].
  BloomOrmUnsupportedOnDialectError(String message)
      : super('Unsupported on dialect: $message');
}

/// Exception thrown when `select_for_update` row locking is attempted outside of an active database transaction.
///
/// Mirrors `OrmError::SelectForUpdateOutsideTransaction`.
///
/// Example:
/// ```dart
/// try {
///   throw BloomOrmSelectForUpdateOutsideTransactionError();
/// } on BloomOrmSelectForUpdateOutsideTransactionError catch (e) {
///   print(e.message);
/// }
/// ```
class BloomOrmSelectForUpdateOutsideTransactionError extends BloomOrmException {
  /// Creates an error indicating `select_for_update` was invoked outside of a transaction.
  BloomOrmSelectForUpdateOutsideTransactionError()
      : super('select_for_update cannot be used outside of a transaction');
}

/// Exception thrown when underlying SQL query execution fails at the driver or database level.
///
/// Wraps the original driver exception [cause] and optional [stackTrace].
///
/// Mirrors `OrmError::Query`.
///
/// Example:
/// ```dart
/// try {
///   await db.execute('MALFORMED SQL QUERY');
/// } on BloomOrmQueryException catch (e) {
///   print('Driver failed with cause: ${e.cause}');
/// }
/// ```
class BloomOrmQueryException extends BloomOrmException {
  /// The underlying error or exception thrown by the database driver.
  final Object cause;

  /// The stack trace associated with [cause], if available.
  final StackTrace? stackTrace;

  /// Creates a [BloomOrmQueryException] wrapping an underlying driver [cause] and optional [stackTrace].
  BloomOrmQueryException(this.cause, [this.stackTrace])
      : super('Database query failed: $cause');
}


