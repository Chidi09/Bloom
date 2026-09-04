import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

class _DomainNotFoundError implements Exception {
  final String thing;
  _DomainNotFoundError(this.thing);
  @override
  String toString() => 'DomainNotFoundError: $thing not found';
}

// Fakes named to match the runtime-type-name switch in BloomErrorMapper.
// Each carries raw internals that must never reach a production response.
class BloomOrmQueryException implements Exception {
  @override
  String toString() =>
      'BloomOrmQueryException: SELECT * FROM users -- db-password=SECRET driver=pg8000';
}

class BloomOrmException implements Exception {
  @override
  String toString() => 'BloomOrmException: connection string SECRET leaked';
}

class BloomStorageException implements Exception {
  @override
  String toString() => 'BloomStorageException: /srv/secret/file SECRET';
}

class MigrationFileNotFoundException implements Exception {
  @override
  String toString() =>
      'MigrationFileNotFoundException: /srv/secret/migrations/001.sql SECRET';
}

class MigrationNonInvertibleException implements Exception {
  @override
  String toString() => 'MigrationNonInvertibleException: SQL SECRET';
}

class MigrationCyclicDependencyException implements Exception {
  @override
  String toString() => 'MigrationCyclicDependencyException: graph SECRET';
}

class MigrationExecutionException implements Exception {
  @override
  String toString() => 'MigrationExecutionException: ALTER TABLE SECRET';
}

class MissingMaxLengthException implements Exception {
  @override
  String toString() => 'MissingMaxLengthException: column SECRET';
}

class UnsupportedDialectOperationException implements Exception {
  @override
  String toString() => 'UnsupportedDialectOperationException: dialect SECRET';
}

class MigrationException implements Exception {
  @override
  String toString() => 'MigrationException: internal SECRET';
}

Future<BloomResponse> _runMiddleware(
  BloomErrorMiddleware middleware,
  Future<BloomResponse> Function() body,
) {
  final req = BloomRequest(method: 'GET', uri: Uri.parse('http://localhost/x'));
  return middleware.handle(req, body).then((r) => r!);
}

void main() {
  group('Typed HTTP exceptions', () {
    test('BloomNotFoundException serializes to a 404 JSON response', () {
      final ex = BloomNotFoundException('Widget 7 not found');
      final response = ex.toResponse();
      expect(response.statusCode, 404);
      expect(ex.toJson()['code'], 'not_found');
      expect(ex.toJson()['message'], 'Widget 7 not found');
    });

    test('BloomValidationFailedException carries field errors in details', () {
      final ex = BloomValidationFailedException(errors: {
        'email': ['is required'],
      });
      expect(ex.statusCode, 422);
      expect(ex.toJson()['details']['errors'], {
        'email': ['is required'],
      });
    });

    test('BloomTooManyRequestsException includes retry-after in details', () {
      final ex = BloomTooManyRequestsException('Slow down', const Duration(seconds: 30));
      expect(ex.statusCode, 429);
      expect(ex.toJson()['details']['retry_after_seconds'], 30);
    });
  });

  group('BloomErrorMapper', () {
    tearDown(BloomErrorMapper.clearCustomMappers);

    test('passes through an already-typed BloomApiException unchanged', () {
      final ex = BloomForbiddenException('nope');
      expect(BloomErrorMapper.map(ex), same(ex));
    });

    test('returns null for a plain unmapped exception with no registered mapper', () {
      expect(BloomErrorMapper.map(_DomainNotFoundError('widget')), isNull);
    });

    test('custom typed mapper translates a domain exception', () {
      BloomErrorMapper.register<_DomainNotFoundError>(
        (e) => BloomNotFoundException(e.toString()),
      );
      final mapped = BloomErrorMapper.map(_DomainNotFoundError('widget'));
      expect(mapped, isA<BloomNotFoundException>());
      expect(mapped!.statusCode, 404);
    });

    test('clearCustomMappers removes previously registered mappers', () {
      BloomErrorMapper.register<_DomainNotFoundError>(
        (e) => BloomNotFoundException(e.toString()),
      );
      BloomErrorMapper.clearCustomMappers();
      expect(BloomErrorMapper.map(_DomainNotFoundError('widget')), isNull);
    });
  });

  group('BloomErrorMiddleware', () {
    test('lets a successful response pass through unchanged', () async {
      final middleware = const BloomErrorMiddleware();
      final response = await _runMiddleware(
        middleware,
        () async => BloomResponse.json({'ok': true}),
      );
      expect(response.statusCode, 200);
    });

    test('renders a thrown BloomApiException with its own status/code', () async {
      final middleware = const BloomErrorMiddleware();
      final response = await _runMiddleware(
        middleware,
        () async => throw BloomConflictException('already exists'),
      );
      expect(response.statusCode, 409);
    });

    test('masks unmapped exceptions in production and hides the raw message', () async {
      final middleware = const BloomErrorMiddleware(environment: 'production');
      final response = await _runMiddleware(
        middleware,
        () async => throw StateError('super secret internal detail'),
      );
      expect(response.statusCode, 500);
      final bodyStr = response.bodyText;
      expect(bodyStr, contains('Internal Server Error'));
      expect(bodyStr, isNot(contains('super secret internal detail')));
    });

    test('exposes the raw message for unmapped exceptions outside production', () async {
      final middleware = const BloomErrorMiddleware(environment: 'local');
      final response = await _runMiddleware(
        middleware,
        () async => throw StateError('a specific dev-only detail'),
      );
      expect(response.statusCode, 500);
      final bodyStr = response.bodyText;
      expect(bodyStr, contains('a specific dev-only detail'));
    });

    test('invokes onError callback with the original error', () async {
      Object? captured;
      final middleware = BloomErrorMiddleware(onError: (e, st) => captured = e);
      await _runMiddleware(
        middleware,
        () async => throw BloomBadRequestException('bad'),
      );
      expect(captured, isA<BloomBadRequestException>());
    });

    group('mapped 500s never leak raw text (#28)', () {
      final cases = <Object>[
        BloomOrmQueryException(),
        BloomOrmException(),
        BloomStorageException(),
        MigrationNonInvertibleException(),
        MigrationCyclicDependencyException(),
        MigrationExecutionException(),
        MissingMaxLengthException(),
        UnsupportedDialectOperationException(),
        MigrationException(),
      ];

      for (final err in cases) {
        test('${err.runtimeType} maps to a generic production-safe message',
            () async {
          final raw = err.toString();
          expect(raw, contains('SECRET'));

          final mapped = BloomErrorMapper.map(err);
          expect(mapped, isNotNull);
          expect(mapped!.statusCode, 500);
          expect(mapped.message, isNot(contains('SECRET')));

          // Middleware renders mapped errors verbatim, so the mapped
          // message itself must already be safe in production…
          final prod = const BloomErrorMiddleware(environment: 'production');
          final res =
              await _runMiddleware(prod, () async => throw mapped);
          expect(res.statusCode, 500);
          expect(res.bodyText, isNot(contains('SECRET')));

          // …while raw details stay reachable via onError.
          Object? captured;
          final withLog = BloomErrorMiddleware(
              environment: 'production',
              onError: (e, st) => captured = e);
          await _runMiddleware(withLog, () async => throw err);
          expect(captured.toString(), contains('SECRET'));
        });
      }

      test('MigrationFileNotFound maps to generic 404 without raw path',
          () async {
        final err = MigrationFileNotFoundException();
        final mapped = BloomErrorMapper.map(err)!;
        expect(mapped.statusCode, 404);
        expect(mapped.message, isNot(contains('SECRET')));
        final prod = const BloomErrorMiddleware(environment: 'production');
        final res = await _runMiddleware(prod, () async => throw mapped);
        expect(res.statusCode, 404);
        expect(res.bodyText, isNot(contains('SECRET')));
      });

      test('mapToHttpException fallback is generic', () {
        final mapped = BloomErrorMapper.mapToHttpException(
            Exception('db-password=SECRET'));
        expect(mapped.statusCode, 500);
        expect(mapped.message, isNot(contains('SECRET')));
      });
    });
  });
}
