import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  setUp(() => BloomEnv.clear());

  group('BloomHttpClient — constructor', () {
    test('reads API_BASE_URL from BloomEnv when no explicit baseUrl', () {
      BloomEnv.loadMap({'API_BASE_URL': 'https://api.example.com'});
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, 'https://api.example.com');
      client.close();
    });

    test('explicit baseUrl overrides BloomEnv', () {
      BloomEnv.loadMap({'API_BASE_URL': 'https://should.be.ignored'});
      final client = BloomHttpClient(
        baseUrl: 'https://explicit.example.com',
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, 'https://explicit.example.com');
      client.close();
    });

    test('baseUrl is null when no env var and no explicit value', () {
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(client.baseUrl, isNull);
      client.close();
    });
  });

  group('BloomHttpClient — HTTP verbs', () {
    late BloomHttpClient client;
    late List<http.BaseRequest> captured;

    setUp(() {
      captured = [];
      client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response(jsonEncode({'ok': true}), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
    });

    tearDown(() => client.close());

    test('get<T> sends GET to resolved path', () async {
      final result = await client.get<Map<String, dynamic>>('/items');
      expect(result, {'ok': true});
      expect(captured.single.method, 'GET');
      expect(captured.single.url.path, '/items');
    });

    test('post<T> sends POST with JSON body', () async {
      await client.post<Map<String, dynamic>>('/items', body: {'name': 'widget'});
      expect(captured.single.method, 'POST');
      final sent = captured.single as http.Request;
      expect(jsonDecode(sent.body), {'name': 'widget'});
    });

    test('put<T> sends PUT', () async {
      await client.put<Map<String, dynamic>>('/items/1', body: {'name': 'updated'});
      expect(captured.single.method, 'PUT');
    });

    test('patch<T> sends PATCH', () async {
      await client.patch<Map<String, dynamic>>('/items/1', body: {'name': 'patched'});
      expect(captured.single.method, 'PATCH');
    });

    test('delete<T> sends DELETE', () async {
      await client.delete<Map<String, dynamic>>('/items/1');
      expect(captured.single.method, 'DELETE');
    });

    test('query parameters are appended to URL', () async {
      await client.get<Map<String, dynamic>>('/search',
          queryParameters: {'q': 'dart', 'page': 2});
      final uri = captured.single.url;
      expect(uri.queryParameters['q'], 'dart');
      expect(uri.queryParameters['page'], '2');
    });

    test('absolute URL bypasses baseUrl', () async {
      await client.get<Map<String, dynamic>>('https://other.host.com/data');
      expect(captured.single.url.host, 'other.host.com');
    });
  });

  group('BloomHttpClient — auth token', () {
    test('static authToken injected as Bearer header', () async {
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        authToken: 'my-secret-token',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      await client.get<dynamic>('/secure');
      expect(captured.single.headers['Authorization'], 'Bearer my-secret-token');
      client.close();
    });

    test('authTokenProvider called per request', () async {
      int callCount = 0;
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () {
          callCount++;
          return 'dynamic-token-$callCount';
        },
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      await client.get<dynamic>('/a');
      await client.get<dynamic>('/b');
      expect(captured[0].headers['Authorization'], 'Bearer dynamic-token-1');
      expect(captured[1].headers['Authorization'], 'Bearer dynamic-token-2');
      client.close();
    });
  });

  group('BloomHttpClient — interceptors', () {
    test('requestInterceptor can mutate headers', () async {
      final captured = <http.BaseRequest>[];
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((req) async {
          captured.add(req);
          return http.Response('null', 200);
        }),
      );
      client.requestInterceptors.add((req) {
        req.headers['X-Custom'] = 'injected';
        return req;
      });
      await client.get<dynamic>('/');
      expect(captured.single.headers['X-Custom'], 'injected');
      client.close();
    });

    test('responseInterceptor can transform response', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient(
            (_) async => http.Response(jsonEncode({'v': 1}), 200)),
      );
      client.responseInterceptors.add((resp) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        body['intercepted'] = true;
        return http.Response(jsonEncode(body), resp.statusCode,
            headers: resp.headers);
      });
      final result = await client.get<Map<String, dynamic>>('/data');
      expect(result['intercepted'], isTrue);
      client.close();
    });
  });

  group('BloomHttpClient — error handling', () {
    test('throws ClientException on 4xx status', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient:
            MockClient((_) async => http.Response('{"error":"not found"}', 404)),
      );
      expect(() => client.get<dynamic>('/missing'),
          throwsA(isA<http.ClientException>()));
      client.close();
    });

    test('throws ClientException on 5xx status', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient:
            MockClient((_) async => http.Response('server error', 500)),
      );
      expect(() => client.get<dynamic>('/crash'),
          throwsA(isA<http.ClientException>()));
      client.close();
    });

    test('returns null for empty 2xx response', () async {
      final client = BloomHttpClient(
        baseUrl: 'https://api.example.com',
        innerClient: MockClient((_) async => http.Response('', 204)),
      );
      final result = await client.get<dynamic>('/empty');
      expect(result, isNull);
      client.close();
    });

    test('throws StateError for relative path without baseUrl', () {
      final client = BloomHttpClient(
        innerClient: MockClient((_) async => http.Response('null', 200)),
      );
      expect(() => client.get<dynamic>('/no-base'), throwsA(isA<StateError>()));
      client.close();
    });
  });
}
