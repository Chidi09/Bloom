// lib/src/errors.dart

/// Base exception for all Bloom ORM errors.
abstract class BloomOrmException implements Exception {
  /// The detailed error message.
  final String message;

  /// Creates a [BloomOrmException] with the given [message].
  const BloomOrmException(this.message);

  @override
  String toString() => message;
}

/// A query for a single object found no matching record.
///
/// Mirrors `OrmError::NotFound`.
class BloomOrmNotFoundError extends BloomOrmException {
  /// The struct/class name of the target model.
  final String model;

  /// Creates an error indicating that no matching [model] record was found.
  BloomOrmNotFoundError({required this.model})
      : super('Model $model not found');
}

/// A query for a single object returned more than one matching record.
///
/// Mirrors `OrmError::MultipleObjectsReturned`.
class BloomOrmMultipleObjectsReturnedError extends BloomOrmException {
  /// The struct/class name of the target model.
  final String model;

  /// Creates an error indicating that multiple [model] records matched a single-object query.
  BloomOrmMultipleObjectsReturnedError({required this.model})
      : super('Multiple $model objects returned');
}

/// A queryset was built in a way that cannot produce valid SQL.
///
/// Mirrors `OrmError::InvalidQuery`.
class BloomOrmInvalidQueryError extends BloomOrmException {
  /// Creates an error indicating invalid query configuration with the given [message].
  BloomOrmInvalidQueryError(String message) : super('Invalid query: $message');
}

/// Specified field name was not found on the model metadata.
///
/// Mirrors `OrmError::FieldNotFound`.
class BloomOrmFieldNotFoundError extends BloomOrmException {
  /// Name of the requested field.
  final String field;

  /// Struct/class name of the target model.
  final String model;

  /// Creates an error indicating that [field] does not exist on [model].
  BloomOrmFieldNotFoundError({required this.field, required this.model})
      : super('Field $field not found on model $model');
}

/// Operation is not supported on the current database dialect.
///
/// Mirrors `OrmError::UnsupportedOnDialect`.
class BloomOrmUnsupportedOnDialectError extends BloomOrmException {
  /// Creates an error indicating that an operation is unsupported with [message].
  BloomOrmUnsupportedOnDialectError(String message)
      : super('Unsupported on dialect: $message');
}

/// `select_for_update` was called outside of a transaction.
///
/// Mirrors `OrmError::SelectForUpdateOutsideTransaction`.
class BloomOrmSelectForUpdateOutsideTransactionError extends BloomOrmException {
  /// Creates an error indicating `select_for_update` was invoked outside of a transaction.
  BloomOrmSelectForUpdateOutsideTransactionError()
      : super('select_for_update cannot be used outside of a transaction');
}

/// An underlying SQL query execution failed.
///
/// Mirrors `OrmError::Query`.
class BloomOrmQueryException extends BloomOrmException {
  /// The underlying error or exception from the database driver.
  final Object cause;

  /// The stack trace associated with [cause], if available.
  final StackTrace? stackTrace;

  /// Creates a [BloomOrmQueryException] wrapping an underlying driver [cause] and optional [stackTrace].
  BloomOrmQueryException(this.cause, [this.stackTrace])
      : super('Database query failed: $cause');
}

