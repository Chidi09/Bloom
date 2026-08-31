import 'dart:io';
import 'package:bloom_security/bloom_security.dart';
import 'package:bloom_server/bloom_server.dart';
import 'test_helpers.dart';

Future<void> runSecurityHeadersTests() async {
  await group('BloomSecurityHeadersMiddleware Tests', () {
    test('Emits standard defense-in-depth security headers', () async {
      const middleware = BloomSecurityHeadersMiddleware();

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/status'),
      );

      final res = await middleware.handle(
          req, () async => BloomResponse.json({'status': 'ok'}));

      expect(res?.headers['x-content-type-options'], 'nosniff');
      expect(res?.headers['x-frame-options'], 'DENY');
      expect(
          res?.headers['referrer-policy'], 'strict-origin-when-cross-origin');
      expect(res?.headers['cross-origin-opener-policy'], 'same-origin');
      expect(res?.headers['cross-origin-resource-policy'], 'same-origin');
      expect(res?.headers['content-security-policy'],
          contains("default-src 'self'"));
      // HSTS must not be sent over plain HTTP
      expect(res?.headers.containsKey('strict-transport-security'), isFalse);
    });

    test('Conditional HSTS: emitted only when HTTPS is detected', () async {
      const middleware = BloomSecurityHeadersMiddleware(
        hstsMaxAge: Duration(days: 180),
        hstsIncludeSubDomains: true,
        hstsPreload: true,
      );

      // 1. Plain HTTP -> No HSTS
      final httpReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/api/test'),
      );
      final httpRes =
          await middleware.handle(httpReq, () async => BloomResponse.json({}));
      expect(
          httpRes?.headers.containsKey('strict-transport-security'), isFalse);

      // 2. Direct HTTPS scheme -> Emits HSTS
      final httpsReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/api/test'),
      );
      final httpsRes =
          await middleware.handle(httpsReq, () async => BloomResponse.json({}));
      expect(httpsRes?.headers['strict-transport-security'],
          contains('max-age=15552000'));
      expect(httpsRes?.headers['strict-transport-security'],
          contains('includeSubDomains'));
      expect(
          httpsRes?.headers['strict-transport-security'], contains('preload'));

      // 3. Proxy forwarded HTTPS -> Emits HSTS
      final proxiedReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/api/test'),
        headers: {'x-forwarded-proto': 'https'},
      );
      final proxiedRes = await middleware.handle(
          proxiedReq, () async => BloomResponse.json({}));
      expect(proxiedRes?.headers['strict-transport-security'],
          contains('max-age=15552000'));
    });

    test('forceHsts emits HSTS even on plain HTTP', () async {
      const middleware = BloomSecurityHeadersMiddleware(
        forceHsts: true,
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/test'),
      );
      final res =
          await middleware.handle(req, () async => BloomResponse.json({}));
      expect(res?.headers.containsKey('strict-transport-security'), isTrue);
    });

    test('API preset sets restrictive API headers', () async {
      final apiMiddleware = BloomSecurityHeadersMiddleware.api(
        customHeaders: {'X-Custom-Security': 'active'},
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/v1/data'),
      );
      final res =
          await apiMiddleware.handle(req, () async => BloomResponse.json({}));

      expect(res?.headers['referrer-policy'], 'no-referrer');
      expect(res?.headers['x-frame-options'], 'DENY');
      expect(res?.headers['content-security-policy'],
          "default-src 'none'; frame-ancestors 'none'");
      expect(res?.headers['x-custom-security'], 'active');
    });
  });
}

void main() async {
  resetTestCounts();
  await runSecurityHeadersTests();
  exitCode = await reportTestResults();
}
