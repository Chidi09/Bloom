import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

class _DomainNotFoundError implements Exception {
  final String thing;
  _DomainNotFoundError(this.thing);
  @override
  String toString() => 'DomainNotFoundError: $thing not found';
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
  });
}
