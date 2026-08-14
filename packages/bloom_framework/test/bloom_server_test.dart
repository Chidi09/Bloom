import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  group('Phase 12: BloomRequest & BloomResponse Models', () {
    test('BloomRequest parses JSON, URL params, and headers accurately', () {
      final payload = jsonEncode({'name': 'Bloom User', 'role': 'admin'});
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('https://app.bloom.dev/api/users?sort=desc&limit=10'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer token_123'},
        params: {'tenant': 'dev'},
        rawBody: Uint8List.fromList(utf8.encode(payload)),
      );

      expect(req.path, '/api/users');
      expect(req.queryParams['sort'], 'desc');
      expect(req.queryParams['limit'], '10');
      expect(req.params['tenant'], 'dev');
      expect(req.headers['authorization'], 'Bearer token_123');

      final data = req.json();
      expect(data['name'], 'Bloom User');
      expect(data['role'], 'admin');
    });

    test('BloomResponse status and body helpers format correctly', () {
      final jsonRes = BloomResponse.json({'created': true}, statusCode: 201);
      expect(jsonRes.statusCode, 201);
      expect(jsonRes.headers['content-type'], contains('application/json'));
      expect(jsonRes.bodyJson['created'], isTrue);

      final htmlRes = BloomResponse.html('<h1>Hello Bloom</h1>');
      expect(htmlRes.statusCode, 200);
      expect(htmlRes.headers['content-type'], contains('text/html'));
      expect(htmlRes.bodyText, '<h1>Hello Bloom</h1>');

      final noContentRes = BloomResponse.noContent();
      expect(noContentRes.statusCode, 204);
      expect(noContentRes.body.isEmpty, isTrue);

      final redirectRes = BloomResponse.redirect('/dashboard');
      expect(redirectRes.statusCode, 302);
      expect(redirectRes.headers['location'], '/dashboard');

      final unauthorizedRes = BloomResponse.unauthorized();
      expect(unauthorizedRes.statusCode, 401);
      expect(unauthorizedRes.bodyJson['error'], 'Unauthorized');
    });
  });

  group('Phase 12: BloomApiRouter & Composable Middleware', () {
    test('Dispatches routes, matches dynamic path parameters, and executes middlewares in order', () async {
      final router = BloomApiRouter();
      final auditLog = <String>[];

      // Global middleware
      router.use(FunctionalBloomMiddleware((req, next) async {
        auditLog.add('global_before');
        final res = await next();
        auditLog.add('global_after');
        return res;
      }));

      // Route with parameter
      router.get(
        '/api/products/:id',
        (req) async {
          auditLog.add('handler_hit:${req.params['id']}');
          return BloomResponse.json({
            'product_id': req.params['id'],
            'title': 'Bloom Framework Book',
          });
        },
        middlewares: [
          FunctionalBloomMiddleware((req, next) async {
            auditLog.add('route_middleware');
            return await next();
          }),
        ],
      );

      // POST route
      router.post('/api/products', (req) async {
        final body = req.json();
        return BloomResponse.json(body, statusCode: 201);
      });

      // 1. Dispatch GET /api/products/42
      final getReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/products/42'),
      );
      final getRes = await router.handleRequest(getReq);

      expect(getRes.statusCode, 200);
      expect(getRes.bodyJson['product_id'], '42');
      expect(auditLog, [
        'global_before',
        'route_middleware',
        'handler_hit:42',
        'global_after',
      ]);

      // 2. Dispatch POST /api/products
      final postReq = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/api/products'),
        rawBody: Uint8List.fromList(utf8.encode(jsonEncode({'name': 'Dart Book'}))),
      );
      final postRes = await router.handleRequest(postReq);
      expect(postRes.statusCode, 201);
      expect(postRes.bodyJson['name'], 'Dart Book');

      // 3. Dispatch unmatched route -> 404
      final notFoundReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/unknown'),
      );
      final notFoundRes = await router.handleRequest(notFoundReq);
      expect(notFoundRes.statusCode, 404);
    });

    test('BloomCorsMiddleware injects CORS headers and handles preflight OPTIONS', () async {
      final router = BloomApiRouter();
      router.use(const BloomCorsMiddleware(allowOrigin: 'https://bloom.dev'));

      router.get('/api/data', (req) => BloomResponse.text('ok'));

      // OPTIONS preflight
      final optionsReq = BloomRequest(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost/api/data'),
      );
      final optionsRes = await router.handleRequest(optionsReq);
      expect(optionsRes.statusCode, 204);
      expect(optionsRes.headers['access-control-allow-origin'], 'https://bloom.dev');
      expect(optionsRes.headers['access-control-allow-methods'], contains('GET, POST'));

      // Normal GET with CORS response headers
      final getReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/data'),
      );
      final getRes = await router.handleRequest(getReq);
      expect(getRes.headers['access-control-allow-origin'], 'https://bloom.dev');
    });

    test('Catch-all and wildcard patterns compile and match any path', () async {
      final router = BloomApiRouter();
      router.all('*', (req) => BloomResponse.text('catchall'));
      router.get('/files/*', (req) => BloomResponse.text('file'));

      final catchAllRes = await router.handleRequest(
        BloomRequest(method: 'GET', uri: Uri.parse('http://localhost/a/b/c')),
      );
      expect(catchAllRes.statusCode, 200);
      expect(catchAllRes.bodyText, 'catchall');

      final fileRes = await router.handleRequest(
        BloomRequest(method: 'GET', uri: Uri.parse('http://localhost/files/x/y.png')),
      );
      expect(fileRes.statusCode, 200);
      expect(fileRes.bodyText, 'file');
    });
  });

  group('Phase 12: Route Loaders, Actions & Declarative SEO Metadata', () {
    test('BloomRouteContext & ActionResult model data loaders and mutations', () {
      final context = BloomRouteContext.fromPath(
        '/products/123?ref=newsletter',
        params: {'id': '123'},
      );

      expect(context.params['id'], '123');
      expect(context.queryParams['ref'], 'newsletter');

      final successAction = ActionResult.success({'updated': true});
      expect(successAction.isSuccess, isTrue);
      expect(successAction.data['updated'], isTrue);

      final errorAction = ActionResult.error('Invalid price', fieldErrors: {
        'price': ['Must be positive'],
      });
      expect(errorAction.isSuccess, isFalse);
      expect(errorAction.errorMessage, 'Invalid price');
      expect(errorAction.fieldErrors['price'], ['Must be positive']);
    });

    test('BloomRouteMetadata renders valid HTML tags, OpenGraph, and JSON-LD', () {
      const metadata = BloomRouteMetadata(
        title: 'Bloom Store - Premium Flutter Tools',
        description: 'Explore the fullstack framework for Flutter & Dart developers.',
        canonical: 'https://bloom.dev/store',
        openGraph: OpenGraph(
          title: 'Bloom Store',
          description: 'Explore the fullstack framework for Flutter & Dart developers.',
          image: 'https://bloom.dev/og.png',
          type: 'website',
          url: 'https://bloom.dev/store',
        ),
        twitterCard: TwitterCard(
          card: 'summary_large_image',
          site: '@BloomFramework',
        ),
        jsonLd: {
          '@context': 'https://schema.org',
          '@type': 'Product',
          'name': 'Bloom Pro',
        },
      );

      final htmlTags = metadata.renderHtmlTags();
      expect(htmlTags, contains('<title>Bloom Store - Premium Flutter Tools</title>'));
      expect(htmlTags, contains('<meta name="description" content="Explore the fullstack framework for Flutter &amp; Dart developers." />'));
      expect(htmlTags, contains('<link rel="canonical" href="https://bloom.dev/store" />'));
      expect(htmlTags, contains('<meta property="og:title" content="Bloom Store" />'));
      expect(htmlTags, contains('<meta property="og:image" content="https://bloom.dev/og.png" />'));
      expect(htmlTags, contains('<meta name="twitter:card" content="summary_large_image" />'));
      expect(htmlTags, contains('<meta name="twitter:site" content="@BloomFramework" />'));
      expect(htmlTags, contains('<script type="application/ld+json">'));
      expect(htmlTags, contains('"@type": "Product"'));
    });
  });
}
