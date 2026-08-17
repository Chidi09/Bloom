// lib/src/error_mapper.dart
import 'http_exception.dart';

typedef ErrorMappingFunction<T> = BloomApiException Function(T error);

/// Registry that translates domain, database, authentication, and validation exceptions
/// into strongly-typed [BloomApiException] instances.
///
/// To prevent pubspec dependency bloat and circular dependencies, [BloomErrorMapper] maps
/// sibling package exceptions (such as `bloom_db`, `bloom_auth_server`, `bloom_storage`,
/// `bloom_validate`, and `bloom_migrate`) by runtime type name string matching and dynamic property
/// extraction, while allowing applications to register strongly-typed custom mappers via
/// [register].
class BloomErrorMapper {
  static final List<_TypedMapperEntry> _customTypedMappers = [];
  static final Map<String, ErrorMappingFunction<Object>> _customNamedMappers = {};

  /// Registers a strongly-typed exception mapping function for type [E].
  ///
  /// ```dart
  /// BloomErrorMapper.register<UserNotFoundException>(
  ///   (e) => BloomNotFoundException('User ${e.userId} was not found'),
  /// );
  /// ```
  static void register<E extends Object>(ErrorMappingFunction<E> mapper) {
    _customTypedMappers.removeWhere((entry) => entry.type == E);
    _customTypedMappers.insert(
      0,
      _TypedMapperEntry(
        E,
        (obj) => obj is E,
        (obj) => mapper(obj as E),
      ),
    );
  }

  /// Registers an exception mapping function by runtime type name.
  static void registerByName(String typeName, ErrorMappingFunction<Object> mapper) {
    _customNamedMappers[typeName] = mapper;
  }

  /// Removes all custom registered mappers (primarily useful for testing).
  static void clearCustomMappers() {
    _customTypedMappers.clear();
    _customNamedMappers.clear();
  }

  /// Maps an unknown [error] into a [BloomApiException].
  ///
  /// If [error] is already a [BloomApiException], it is returned as-is.
  /// Otherwise, custom typed mappers, custom named mappers, and built-in type name
  /// mappers are checked in order. If no mapping is found, returns `null`.
  static BloomApiException? map(Object error) {
    if (error is BloomApiException) {
      return error;
    }

    // 1. Check custom typed mappers
    for (final entry in _customTypedMappers) {
      if (entry.isMatch(error)) {
        try {
          return entry.mapper(error);
        } catch (_) {}
      }
    }

    final typeName = error.runtimeType.toString();

    // 2. Check custom named mappers
    if (_customNamedMappers.containsKey(typeName)) {
      try {
        return _customNamedMappers[typeName]!(error);
      } catch (_) {}
    }

    // 3. Check built-in mappings by type name string & standard Dart types
    return _mapBuiltIn(error, typeName);
  }

  /// Resolves [error] into a [BloomApiException], falling back to [BloomInternalException]
  /// if no mapping exists.
  static BloomApiException mapToHttpException(Object error) {
    final mapped = map(error);
    if (mapped != null) return mapped;

    return BloomInternalException(error.toString());
  }

  static BloomApiException? _mapBuiltIn(Object error, String typeName) {
    // Standard Dart Core Exceptions
    if (error is FormatException) {
      return BloomBadRequestException('Invalid format: ${error.message}');
    }
    if (error is RangeError) {
      return BloomBadRequestException('Value out of range: ${error.message ?? error.toString()}');
    }
    if (error is ArgumentError) {
      return BloomBadRequestException('Invalid argument: ${error.message ?? error.toString()}');
    }
    // Deliberately NOT mapping StateError/UnsupportedError to a typed
    // BloomInternalException here. Doing so used to carry the raw exception
    // message straight into a "deliberately thrown" 500 response, which
    // BloomErrorMiddleware always renders verbatim regardless of
    // environment — bypassing production masking for exactly the kind of
    // unexpected internal error that masking exists to protect. Leaving
    // these unmapped (returning null) routes them through
    // BloomErrorMiddleware's unmapped-exception branch instead, which
    // correctly masks the message in production and only shows it in
    // local/dev.

    // Bloom DB / ORM Mappings (bloom_db)
    switch (typeName) {
      case 'BloomOrmNotFoundError':
        final model = _tryGetProperty(error, 'model') ?? 'Resource';
        final message = _tryGetProperty(error, 'message') ?? '$model not found';
        return BloomNotFoundException(message.toString(), {'model': model});

      case 'BloomOrmMultipleObjectsReturnedError':
        final model = _tryGetProperty(error, 'model') ?? 'Resource';
        return BloomConflictException('Multiple $model records returned when only one was expected');

      case 'BloomOrmInvalidQueryError':
        final message = _tryGetProperty(error, 'message') ?? error.toString();
        return BloomBadRequestException(message.toString());

      case 'BloomOrmFieldNotFoundError':
        final field = _tryGetProperty(error, 'field');
        final model = _tryGetProperty(error, 'model');
        return BloomBadRequestException(
          'Field ${field ?? ""} not found on model ${model ?? ""}'.trim(),
          {if (field != null) 'field': field, if (model != null) 'model': model},
        );

      case 'BloomOrmUnsupportedOnDialectError':
      case 'BloomOrmSelectForUpdateOutsideTransactionError':
      case 'BloomOrmQueryException':
      case 'BloomOrmException':
        return BloomInternalException(error.toString());

      // Bloom Validation Mappings (bloom_validate)
      case 'BloomValidationException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Validation failed';
        final errors = _tryGetProperty(error, 'errors');
        return BloomValidationFailedException(
          message: message,
          errors: errors,
        );

      // Bloom Storage Mappings (bloom_storage)
      case 'BloomFileNotFoundException':
        final path = _tryGetProperty(error, 'path');
        final message = _tryGetProperty(error, 'message')?.toString() ??
            (path != null ? 'File not found at storage path: "$path"' : 'File not found');
        return BloomNotFoundException(message, {if (path != null) 'path': path});

      case 'BloomStoragePathTraversalException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Path traversal detected';
        return BloomForbiddenException(message);

      case 'BloomStorageAuthException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Storage authentication failed';
        return BloomUnauthorizedException(message);

      case 'BloomStorageServerException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Storage service error';
        final statusCode = _tryGetProperty(error, 'statusCode');
        return BloomInternalException(message, {if (statusCode != null) 'upstream_status': statusCode});

      case 'BloomStorageException':
        return BloomInternalException(error.toString());

      // Bloom Auth Server Mappings (bloom_auth_server)
      case 'SessionTokenException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Invalid or expired session token';
        return BloomUnauthorizedException(message);

      case 'PasswordResetException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Invalid or expired password reset token';
        return BloomBadRequestException(message);

      case 'PasswordHashException':
        return const BloomInternalException('Authentication system error');

      case 'RateLimitException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Too many requests. Please slow down.';
        final retryAfter = _tryGetProperty(error, 'retryAfter');
        return BloomTooManyRequestsException(
          message,
          retryAfter is Duration ? retryAfter : null,
        );

      case 'AccountLockedException':
        final message = _tryGetProperty(error, 'message')?.toString() ?? 'Account is locked due to too many failed attempts';
        return BloomForbiddenException(message);

      // Bloom Migrate Mappings (bloom_migrate)
      case 'MigrationFileNotFoundException':
        return BloomNotFoundException(error.toString());

      case 'MigrationNonInvertibleException':
      case 'MigrationCyclicDependencyException':
      case 'MigrationExecutionException':
      case 'MissingMaxLengthException':
      case 'UnsupportedDialectOperationException':
      case 'MigrationException':
        return BloomInternalException(error.toString());
    }

    return null;
  }

  static dynamic _tryGetProperty(Object target, String propertyName) {
    try {
      final dynamic obj = target;
      switch (propertyName) {
        case 'model':
          return obj.model;
        case 'field':
          return obj.field;
        case 'message':
          return obj.message;
        case 'errors':
          return obj.errors;
        case 'path':
          return obj.path;
        case 'statusCode':
          return obj.statusCode;
        case 'retryAfter':
          return obj.retryAfter;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

class _TypedMapperEntry {
  final Type type;
  final bool Function(Object) isMatch;
  final ErrorMappingFunction<Object> mapper;

  _TypedMapperEntry(this.type, this.isMatch, this.mapper);
}
