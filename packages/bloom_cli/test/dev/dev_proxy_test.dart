// test/dev/dev_proxy_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/dev_proxy.dart';
import 'package:bloom_cli/src/dev/live_reload_server.dart';

void main() {
  group('BloomDevProxyRule', () {
    test('parses from YAML map correctly', () {
      final rule = BloomDevProxyRule.fromYaml('/api', {
        'target': 'http://127.0.0.1:8090',
        'strip_prefix': true,
      });

      expect(rule.pathPrefix, '/api');
      expect(rule.targetUri, Uri.parse('http://127.0.0.1:8090'));
      expect(rule.stripPrefix, isTrue);
    });

    test('defaults stripPrefix to false', () {
      final rule = BloomDevProxyRule.fromYaml('api/v2', {
        'target': 'https://api.example.com',
      });

      expect(rule.pathPrefix, '/api/v2');
      expect(rule.targetUri, Uri.parse('https://api.example.com'));
      expect(rule.stripPrefix, isFalse);
    });

    test('throws FormatException when target is missing or invalid', () {
      expect(
        () => BloomDevProxyRule.fromYaml('/api', {'strip_prefix': true}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BloomDevProxyRule.fromYaml('/api', 'not-a-map'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BloomDevProxyRule.fromYaml('/api', {'target': 'not a uri!'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('matches prefix correctly on segment boundaries', () {
      final rule = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:8090'),
      );

      expect(rule.matches('/api'), isTrue);
      expect(rule.matches('/api/'), isTrue);
      expect(rule.matches('/api/users'), isTrue);
      expect(rule.matches('/api/users/123/posts'), isTrue);
      expect(rule.matches('/apikeys'), isFalse);
      expect(rule.matches('/other'), isFalse);
    });

    test('resolves target URI with stripPrefix = false', () {
      final rule = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:8090/backend'),
        stripPrefix: false,
      );

      final uri = rule.resolveTargetUri(Uri.parse('http://localhost:8080/api/users?limit=10'));
      expect(uri.toString(), 'http://127.0.0.1:8090/backend/api/users?limit=10');
    });

    test('resolves target URI with stripPrefix = true', () {
      final rule = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:8090/v1'),
        stripPrefix: true,
      );

      final uri = rule.resolveTargetUri(Uri.parse('http://localhost:8080/api/users?sort=asc'));
      expect(uri.toString(), 'http://127.0.0.1:8090/v1/users?sort=asc');
    });

    test('longest prefix sorting resolves correctly', () {
      final rules = [
        BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('http://127.0.0.1:8090/v1'),
        ),
        BloomDevProxyRule(
          pathPrefix: '/api/v2',
          targetUri: Uri.parse('http://127.0.0.1:8090/v2'),
        ),
      ]..sort((a, b) => b.pathPrefix.length.compareTo(a.pathPrefix.length));

      expect(rules.first.pathPrefix, '/api/v2');
      expect(rules.last.pathPrefix, '/api');

      final targetRule = rules.firstWhere((r) => r.matches('/api/v2/items'));
      expect(targetRule.pathPrefix, '/api/v2');
      expect(targetRule.targetUri.path, '/v2');
    });
  });

  group('BloomDevProxy Forwarding', () {
    late HttpServer upstreamServer;
    late int upstreamPort;
    late BloomDevProxy proxy;
    late HttpServer proxyHostServer;
    late int proxyPort;
    final capturedRequests = <Map<String, dynamic>>[];

    setUp(() async {
      capturedRequests.clear();
      proxy = BloomDevProxy();

      // Start mock upstream server
      upstreamServer = await HttpServer.bind('127.0.0.1', 0);
      upstreamPort = upstreamServer.port;

      upstreamServer.listen((req) async {
        final bodyStr = await utf8.decodeStream(req);
        final headersMap = <String, String>{};
        req.headers.forEach((k, v) => headersMap[k] = v.join(', '));

        capturedRequests.add({
          'method': req.method,
          'uri': req.uri.toString(),
          'headers': headersMap,
          'body': bodyStr,
        });

        // The rule under test uses stripPrefix: false, so the upstream
        // legitimately receives the full '/api/...' path. Matching on the
        // bare '/echo' here never fired, which made this stub answer from the
        // fallback branch and look like the proxy had dropped the response
        // header it never actually set.
        if (req.uri.path == '/api/echo') {
          req.response.statusCode = 200;
          req.response.headers.set('content-type', 'application/json');
          req.response.headers.set('x-upstream-header', 'bloom-val');
          req.response.write(jsonEncode({
            'echo': bodyStr,
            'receivedHeaders': headersMap,
          }));
          await req.response.close();
        } else if (req.uri.path == '/api/error') {
          req.response.statusCode = 400;
          req.response.headers.set('content-type', 'application/json');
          req.response.write(jsonEncode({'error': 'Bad Request'}));
          await req.response.close();
        } else {
          req.response.statusCode = 200;
          req.response.write('OK: ${req.uri.path}');
          await req.response.close();
        }
      });

      // Start a test host server that uses BloomDevProxy
      final rule = BloomDevProxyRule(
        pathPrefix: '/api',
        targetUri: Uri.parse('http://127.0.0.1:$upstreamPort'),
        stripPrefix: false,
      );

      proxyHostServer = await HttpServer.bind('127.0.0.1', 0);
      proxyPort = proxyHostServer.port;

      proxyHostServer.listen((req) async {
        if (rule.matches(req.uri.path)) {
          await proxy.forward(req, rule);
        } else {
          req.response.statusCode = 404;
          req.response.write('Not Found');
          await req.response.close();
        }
      });
    });

    tearDown(() async {
      await proxyHostServer.close(force: true);
      await upstreamServer.close(force: true);
      await proxy.close(force: true);
    });

    test('forwards GET request with query params and headers', () async {
      final res = await http.get(
        Uri.parse('http://127.0.0.1:$proxyPort/api/test?query=bloom'),
        headers: {'X-Custom-Header': 'HelloProxy'},
      );

      expect(res.statusCode, 200);
      expect(res.body, 'OK: /api/test');

      expect(capturedRequests.length, 1);
      final captured = capturedRequests.first;
      expect(captured['method'], 'GET');
      expect(captured['uri'], '/api/test?query=bloom');
      expect(captured['headers']['x-custom-header'], 'HelloProxy');
      expect(captured['headers']['x-forwarded-for'], isNotNull);
      expect(captured['headers']['x-forwarded-proto'], 'http');
    });

    test('forwards POST request with JSON body and streams response', () async {
      final payload = jsonEncode({'message': 'Hello from client'});
      final res = await http.post(
        Uri.parse('http://127.0.0.1:$proxyPort/api/echo'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      expect(res.statusCode, 200);
      expect(res.headers['x-upstream-header'], 'bloom-val');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      expect(data['echo'], payload);
    });

    test('returns 502 Bad Gateway on upstream connection failure', () async {
      // Point rule to an unused port
      final deadRule = BloomDevProxyRule(
        pathPrefix: '/dead',
        targetUri: Uri.parse('http://127.0.0.1:59999'),
      );

      final deadHostServer = await HttpServer.bind('127.0.0.1', 0);
      deadHostServer.listen((req) async {
        await proxy.forward(req, deadRule);
      });

      final res = await http.get(Uri.parse('http://127.0.0.1:${deadHostServer.port}/dead/ping'));

      expect(res.statusCode, 502);
      expect(res.body, contains('502 Bad Gateway'));
      expect(res.body, contains('59999'));

      await deadHostServer.close(force: true);
    });
  });

  group('BloomLiveReloadServer with Proxy Rules', () {
    late Directory tempWebDir;
    late BloomLiveReloadServer devServer;
    late int devPort;
    late HttpServer mockApiBackend;
    late int apiPort;

    setUp(() async {
      tempWebDir = await Directory.systemTemp.createTemp('bloom_proxy_test_');
      final indexHtml = File('${tempWebDir.path}/index.html');
      await indexHtml.writeAsString('<!DOCTYPE html><html><body><h1>Static Page</h1></body></html>');

      // Start mock API backend
      mockApiBackend = await HttpServer.bind('127.0.0.1', 0);
      apiPort = mockApiBackend.port;
      mockApiBackend.listen((req) async {
        if (req.uri.path == '/tasks') {
          req.response.statusCode = 200;
          req.response.headers.set('content-type', 'application/json');
          req.response.write(jsonEncode([{'id': 1, 'title': 'Backend Task'}]));
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          req.response.write('Not Found');
          await req.response.close();
        }
      });

      // Start LiveReloadServer with proxy rule
      devServer = BloomLiveReloadServer(
        webDir: tempWebDir,
        host: '127.0.0.1',
        port: 0,
        proxyRules: [
          BloomDevProxyRule(
            pathPrefix: '/api',
            targetUri: Uri.parse('http://127.0.0.1:$apiPort'),
            stripPrefix: true,
          ),
        ],
      );
      await devServer.start();
      devPort = devServer.server!.port;
    });

    tearDown(() async {
      await devServer.stop();
      await mockApiBackend.close(force: true);
      if (tempWebDir.existsSync()) {
        await tempWebDir.delete(recursive: true);
      }
    });

    test('serves static files on non-proxy paths', () async {
      final res = await http.get(Uri.parse('http://127.0.0.1:$devPort/'));
      expect(res.statusCode, 200);
      expect(res.body, contains('Static Page'));
    });

    test('proxies /api/tasks to backend and strips prefix', () async {
      final res = await http.get(Uri.parse('http://127.0.0.1:$devPort/api/tasks'));
      expect(res.statusCode, 200);
      expect(res.body, contains('Backend Task'));
    });
  });
}
