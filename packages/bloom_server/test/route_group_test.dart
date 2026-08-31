// test/route_group_test.dart
import 'dart:async';
import 'dart:convert';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRouteGroup - Nesting & Path Parameters', () {
    test('nested prefixes and parameters resolve correctly', () async {
      final router = BloomApiRouter();

      router.group('/api', (api) {
        api.group('/v1', (v1) {
          v1.group('/orgs/:orgId', (orgs) {
            orgs.get('/users/:userId', (req) async {
              return BloomResponse.json({
                'orgId': req.params['orgId'],
                'userId': req.params['userId'],
              });
            });
          });
        });
      });

      final req = BloomRequest(
        method: 'GET',
        uri:
            Uri.parse('http://localhost:8080/api/v1/orgs/org-99/users/user-42'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);

      final data = res.bodyJson as Map<String, dynamic>;
      expect(data['orgId'], 'org-99');
      expect(data['userId'], 'user-42');
    });

    test('group prefix normalization handles slashes deterministically',
        () async {
      final router = BloomApiRouter();

      router.group('v1/', (v1) {
        v1.group('/items/', (items) {
          items.get(':id', (req) async {
            return BloomResponse.text('item ${req.params['id']}');
          });
          items.get('', (req) async {
            return BloomResponse.text('all items');
          });
        });
      });

      final reqSingle = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/v1/items/456'),
      );
      final resSingle = await router.handle(reqSingle);
      expect(resSingle.statusCode, 200);
      expect(resSingle.bodyText, 'item 456');

      final reqList = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/v1/items'),
      );
      final resList = await router.handle(reqList);
      expect(resList.statusCode, 200);
      expect(resList.bodyText, 'all items');
    });

    test('all HTTP verbs supported on route groups', () async {
      final router = BloomApiRouter();

      router.group('/resources', (g) {
        g.get('/item', (req) async => BloomResponse.text('GET'));
        g.post('/item', (req) async => BloomResponse.text('POST'));
        g.put('/item', (req) async => BloomResponse.text('PUT'));
        g.patch('/item', (req) async => BloomResponse.text('PATCH'));
        g.delete('/item', (req) async => BloomResponse.text('DELETE'));
        g.options('/item', (req) async => BloomResponse.text('OPTIONS'));
      });

      for (final method in [
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'OPTIONS'
      ]) {
        final req = BloomRequest(
          method: method,
          uri: Uri.parse('http://localhost:8080/resources/item'),
        );
        final res = await router.handle(req);
        expect(res.statusCode, 200);
        expect(res.bodyText, method);
      }
    });

    test('explicit all route inside group matches any method', () async {
      final router = BloomApiRouter();

      router.group('/wildcard', (g) {
        g.all(
            '/*', (req) async => BloomResponse.text('${req.method} wildcard'));
      });

      for (final method in ['GET', 'POST', 'PUT', 'DELETE', 'CUSTOM']) {
        final req = BloomRequest(
          method: method,
          uri: Uri.parse('http://localhost:8080/wildcard/anything/deep'),
        );
        final res = await router.handle(req);
        expect(res.statusCode, 200);
        expect(res.bodyText, '$method wildcard');
      }
    });
  });

  group('BloomRouteGroup - Middleware Inheritance Order', () {
    test(
        'middleware executes in order: global -> parent group -> child group -> route -> handler',
        () async {
      final router = BloomApiRouter();
      final executionOrder = <String>[];

      BloomMiddleware track(String name) {
        return FunctionalBloomMiddleware((req, next) async {
          executionOrder.add(name);
          final res = await next();
          executionOrder.add('$name:after');
          return res;
        });
      }

      router.use(track('global'));

      router.group('/api', (api) {
        api.use(track('parent:use'));

        api.group('/v1', (v1) {
          v1.use(track('child:use'));

          v1.get(
            '/resource',
            (req) async {
              executionOrder.add('handler');
              return BloomResponse.text('ok');
            },
            middlewares: [track('route:param')],
          );
        }, middlewares: [track('child:param')]);
      }, middlewares: [track('parent:param')]);

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/v1/resource'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);
      expect(res.bodyText, 'ok');

      expect(executionOrder, [
        'global',
        'parent:param',
        'parent:use',
        'child:param',
        'child:use',
        'route:param',
        'handler',
        'route:param:after',
        'child:use:after',
        'child:param:after',
        'parent:use:after',
        'parent:param:after',
        'global:after',
      ]);
    });
  });

  group('HTTP Method Matching & Allow Header Semantics', () {
    test('DELETE against GET/POST returns 405 with deterministic Allow header',
        () async {
      final router = BloomApiRouter();

      router.get('/api/users', (req) async => BloomResponse.json([]));
      router.post(
          '/api/users', (req) async => BloomResponse.json({}, statusCode: 201));

      final req = BloomRequest(
        method: 'DELETE',
        uri: Uri.parse('http://localhost:8080/api/users'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 405);
      expect(res.headers['allow'], 'GET, HEAD, POST, OPTIONS');

      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['error'], 'Method Not Allowed');
      expect(json['statusCode'], 405);
    });

    test('implicit OPTIONS returns 204 with deterministic Allow header',
        () async {
      final router = BloomApiRouter();

      router.get('/api/items', (req) async => BloomResponse.json([]));
      router.post(
          '/api/items', (req) async => BloomResponse.json({}, statusCode: 201));
      router.put('/api/items', (req) async => BloomResponse.json({}));

      final req = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/items'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 204);
      expect(res.headers['allow'], 'GET, HEAD, POST, PUT, OPTIONS');
      expect(res.body, isEmpty);
    });

    test(
        'BloomCorsMiddleware augments synthesized OPTIONS 204 and preserves 404 for missing routes',
        () async {
      final router = BloomApiRouter();
      router.use(const BloomCorsMiddleware());

      router.get('/items', (req) async => BloomResponse.json(['item1']));

      final reqOptions = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/items'),
      );
      final resOptions = await router.handle(reqOptions);
      expect(resOptions.statusCode, 204);
      expect(resOptions.headers['allow'], 'GET, HEAD, OPTIONS');
      expect(resOptions.headers['access-control-allow-origin'], '*');
      expect(resOptions.headers['access-control-allow-methods'],
          'GET, POST, PUT, DELETE, PATCH, OPTIONS');
      expect(resOptions.headers['access-control-allow-headers'],
          'Content-Type, Authorization, X-Requested-With');

      final reqMissing = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/missing'),
      );
      final resMissing = await router.handle(reqMissing);
      expect(resMissing.statusCode, 404);
      expect(resMissing.headers['access-control-allow-origin'], '*');
      expect(resMissing.headers['access-control-allow-methods'],
          'GET, POST, PUT, DELETE, PATCH, OPTIONS');
    });

    test('explicit OPTIONS wins over implicit 204 handler', () async {
      final router = BloomApiRouter();

      router.get('/api/custom', (req) async => BloomResponse.text('get'));
      router.options('/api/custom', (req) async {
        return BloomResponse.noContent(headers: {
          'x-custom-options': 'true',
          'access-control-allow-origin': 'https://custom.com',
        });
      });

      final req = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/custom'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 204);
      expect(res.headers['x-custom-options'], 'true');
      expect(res.headers['access-control-allow-origin'], 'https://custom.com');
    });

    test('unmatched path remains 404 for any method including OPTIONS',
        () async {
      final router = BloomApiRouter();

      router.get('/api/known', (req) async => BloomResponse.text('known'));

      final reqGet = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/unknown'),
      );
      final resGet = await router.handle(reqGet);
      expect(resGet.statusCode, 404);

      final reqOptions = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:8080/api/unknown'),
      );
      final resOptions = await router.handle(reqOptions);
      expect(resOptions.statusCode, 404);

      final reqDelete = BloomRequest(
        method: 'DELETE',
        uri: Uri.parse('http://localhost:8080/api/unknown'),
      );
      final resDelete = await router.handle(reqDelete);
      expect(resDelete.statusCode, 404);
    });

    test('HEAD delegates to GET and suppresses body bytes', () async {
      final router = BloomApiRouter();

      router.get('/api/data', (req) async {
        return BloomResponse.json({
          'message': 'hello world',
          'nested': {'count': 123},
        });
      });

      final req = BloomRequest(
        method: 'HEAD',
        uri: Uri.parse('http://localhost:8080/api/data'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('application/json'));
      expect(res.body, isEmpty);
      expect(res.bodyText, isEmpty);
    });

    test('HEAD cancels streaming body and returns empty payload', () async {
      final router = BloomApiRouter();
      var streamCancelled = false;

      final controller = StreamController<List<int>>(
        onCancel: () => streamCancelled = true,
      );
      controller.add(utf8.encode('stream payload'));

      router.get('/api/stream', (req) async {
        return BloomResponse.stream(controller.stream,
            contentType: 'text/plain');
      });

      final req = BloomRequest(
        method: 'HEAD',
        uri: Uri.parse('http://localhost:8080/api/stream'),
      );

      final res = await router.handle(req);
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], 'text/plain');
      expect(res.body, isEmpty);
      expect(streamCancelled, isTrue);

      await controller.close();
    });
  });
}
