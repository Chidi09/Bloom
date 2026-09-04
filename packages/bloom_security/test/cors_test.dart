import 'package:bloom_security/bloom_security.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

void main() {
  group('BloomAdvancedCorsMiddleware Security Tests', () {
    test(
        'Defaults to deny-by-default (empty allowedOrigins rejects cross-origin)',
        () async {
      final cors = BloomAdvancedCorsMiddleware();
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/data'),
        headers: {'origin': 'https://evil.com'},
      );

      bool downstreamCalled = false;
      final res = await cors.handle(req, () async {
        downstreamCalled = true;
        return BloomResponse.json({'ok': true});
      });

      expect(downstreamCalled, isFalse);
      expect(res?.statusCode, 403);
      expect(res?.headers.containsKey('Access-Control-Allow-Origin'), isFalse);
      expect(res?.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test(
        'Throws ArgumentError if wildcard origin is configured with allowCredentials = true',
        () {
      expect(() {
        BloomAdvancedCorsMiddleware(
          allowedOrigins: const ['*'],
          allowCredentials: true,
        );
      }, throwsArgumentError);
    });

    test(
        'Permissive factory sets allowCredentials = false and does not reflect arbitrary origins',
        () async {
      final cors = BloomAdvancedCorsMiddleware.permissive();
      expect(cors.allowCredentials, isFalse);
      expect(cors.allowedOrigins, equals(['*']));

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/public'),
        headers: {'origin': 'https://random-site.com'},
      );

      final res = await cors.handle(req, () async {
        return BloomResponse.json({'public': true});
      });

      expect(res?.statusCode, 200);
      expect(res?.headers['access-control-allow-origin'], '*');
      expect(res?.headers.containsKey('access-control-allow-credentials'),
          isFalse);
    });

    test('Strict factory allows configured explicit origins', () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://app.bloom.dev', 'https://admin.bloom.dev'],
        allowCredentials: true,
      );

      final allowedReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/me'),
        headers: {'origin': 'https://app.bloom.dev'},
      );

      final allowedRes = await cors.handle(allowedReq, () async {
        return BloomResponse.json({'user': 'alice'});
      });

      expect(allowedRes?.statusCode, 200);
      expect(allowedRes?.headers['access-control-allow-origin'],
          'https://app.bloom.dev');
      expect(allowedRes?.headers['access-control-allow-credentials'], 'true');

      final deniedReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/me'),
        headers: {'origin': 'https://attacker.com'},
      );

      bool handlerCalled = false;
      final deniedRes = await cors.handle(deniedReq, () async {
        handlerCalled = true;
        return BloomResponse.json({'user': 'alice'});
      });

      expect(handlerCalled, isFalse);
      expect(deniedRes?.statusCode, 403);
      expect(deniedRes?.headers.containsKey('access-control-allow-origin'),
          isFalse);
    });

    test(
        'Preflight OPTIONS: valid preflight returns 204 with headers and max-age',
        () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://trusted.com'],
        allowedMethods: ['GET', 'POST', 'PUT'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Custom-Header'],
        allowCredentials: true,
        maxAge: const Duration(hours: 2),
      );

      final preflightReq = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/resource'),
        headers: {
          'origin': 'https://trusted.com',
          'access-control-request-method': 'POST',
          'access-control-request-headers':
              'authorization, x-custom-header, content-type',
        },
      );

      bool nextInvoked = false;
      final res = await cors.handle(preflightReq, () async {
        nextInvoked = true;
        return BloomResponse.json({});
      });

      expect(nextInvoked, isFalse);
      expect(res?.statusCode, 204);
      expect(
          res?.headers['access-control-allow-origin'], 'https://trusted.com');
      expect(res?.headers['access-control-allow-credentials'], 'true');
      expect(res?.headers['access-control-allow-methods'], 'GET, POST, PUT');
      expect(res?.headers['access-control-max-age'], '7200');
      expect(res?.headers['vary'], contains('Origin'));
    });

    test(
        'Preflight OPTIONS: rejects disallowed origin with 403 and zero allow headers',
        () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://trusted.com'],
      );

      final preflightReq = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/resource'),
        headers: {
          'origin': 'https://evil.com',
          'access-control-request-method': 'POST',
        },
      );

      final res =
          await cors.handle(preflightReq, () async => BloomResponse.json({}));
      expect(res?.statusCode, 403);
      expect(res?.headers.containsKey('access-control-allow-origin'), isFalse);
      expect(res?.headers.containsKey('access-control-allow-methods'), isFalse);
    });

    test(
        'Preflight OPTIONS: rejects disallowed method with 403 and zero allow headers',
        () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://trusted.com'],
        allowedMethods: ['GET', 'POST'],
      );

      final preflightReq = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/resource'),
        headers: {
          'origin': 'https://trusted.com',
          'access-control-request-method': 'DELETE',
        },
      );

      final res =
          await cors.handle(preflightReq, () async => BloomResponse.json({}));
      expect(res?.statusCode, 403);
      expect(res?.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test(
        'Preflight OPTIONS: rejects disallowed request header case-insensitively',
        () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://trusted.com'],
        allowedHeaders: ['Content-Type', 'Authorization'],
      );

      final preflightReq = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/resource'),
        headers: {
          'origin': 'https://trusted.com',
          'access-control-request-method': 'POST',
          'access-control-request-headers':
              'Content-Type, X-Injected-Evil-Header',
        },
      );

      final res =
          await cors.handle(preflightReq, () async => BloomResponse.json({}));
      expect(res?.statusCode, 403);
      expect(res?.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test(
        'Non-CORS same-origin request without Origin header passes through cleanly',
        () async {
      final cors = BloomAdvancedCorsMiddleware();
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/health'),
        headers: {},
      );

      bool downstreamCalled = false;
      final res = await cors.handle(req, () async {
        downstreamCalled = true;
        return BloomResponse.json({'status': 'ok'});
      });

      expect(downstreamCalled, isTrue);
      expect(res?.statusCode, 200);
      expect(res?.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('Exposed headers are attached when configured', () async {
      final cors = BloomAdvancedCorsMiddleware.strict(
        origins: ['https://myapp.com'],
        exposedHeaders: ['X-Trace-Id', 'X-Total-Count'],
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/items'),
        headers: {'origin': 'https://myapp.com'},
      );

      final res = await cors.handle(req, () async => BloomResponse.json([]));
      expect(res?.statusCode, 200);
      expect(res?.headers['access-control-expose-headers'],
          'X-Trace-Id, X-Total-Count');
    });
  });
}
