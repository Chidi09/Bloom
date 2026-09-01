// test/route_typegen_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/generator/route_typegen.dart';
import 'package:bloom_cli/src/utils/project.dart';

void main() {
  group('RouteTypegen Parser', () {
    test('extracts single-quoted and double-quoted route paths', () {
      const source = '''
final routes = [
  BloomRoute('/', (params) => home(params)),
  BloomRoute("/cart", (params) => cart(params)),
  BloomRoute(r'/raw/path', (params) => raw(params)),
];
''';
      final parsed = RouteTypegen.parseSource(source);
      expect(parsed.length, 3);
      expect(parsed[0].path, '/');
      expect(parsed[0].params, isEmpty);
      expect(parsed[0].hasWildcard, isFalse);

      expect(parsed[1].path, '/cart');
      expect(parsed[1].params, isEmpty);
      expect(parsed[1].hasWildcard, isFalse);

      expect(parsed[2].path, '/raw/path');
      expect(parsed[2].params, isEmpty);
      expect(parsed[2].hasWildcard, isFalse);
    });

    test('extracts dynamic parameters and wildcards correctly', () {
      const source = '''
final routes = [
  BloomRoute('/p/:slug', (params) => product(params)),
  BloomRoute('/users/:userId/posts/:postId', (params) => userPost(params)),
  BloomRoute('/docs/*', (params) => docs(params)),
  BloomRoute('/docs/:category/*', (params) => categoryDocs(params)),
];
''';
      final parsed = RouteTypegen.parseSource(source);
      expect(parsed.length, 4);

      expect(parsed[0].path, '/p/:slug');
      expect(parsed[0].params, ['slug']);
      expect(parsed[0].hasWildcard, isFalse);

      expect(parsed[1].path, '/users/:userId/posts/:postId');
      expect(parsed[1].params, ['userId', 'postId']);
      expect(parsed[1].hasWildcard, isFalse);

      expect(parsed[2].path, '/docs/*');
      expect(parsed[2].params, isEmpty);
      expect(parsed[2].hasWildcard, isTrue);

      expect(parsed[3].path, '/docs/:category/*');
      expect(parsed[3].params, ['category']);
      expect(parsed[3].hasWildcard, isTrue);
    });

    test('deduplicates identical route paths and emits warning', () {
      const source = '''
final router = BloomRouter([
  BloomRoute('/', (params) => home(params)),
  BloomRoute('/cart', (params) => cart(params)),
], notFound: BloomRoute('/', (params) => home(params)));
''';
      final warnings = <String>[];
      final parsed = RouteTypegen.parseSource(
        source,
        onWarning: (w) => warnings.add(w),
      );

      expect(parsed.length, 2);
      expect(parsed.map((r) => r.path).toList(), ['/', '/cart']);
      expect(warnings.length, 1);
      expect(warnings.first, contains('Duplicate route path "/"'));
    });

    test('skips BloomRoute.shell calls without failing', () {
      const source = '''
final router = BloomRouter([
  BloomRoute.shell(
    builder: (child, params) => AppShell(child: child),
    children: [
      BloomRoute('/dashboard', (params) => Dashboard(params)),
    ],
  ),
  BloomRoute('/login', (params) => Login(params)),
]);
''';
      final parsed = RouteTypegen.parseSource(source);
      // BloomRoute.shell itself is skipped, but nested BloomRoute('/dashboard') is parsed
      expect(parsed.length, 2);
      expect(parsed[0].path, '/dashboard');
      expect(parsed[1].path, '/login');
    });

    test('parses multiline BloomRoute declarations', () {
      const source = '''
final router = BloomRouter([
  BloomRoute(
    '/admin/products/:id',
    (params) => adminProductForm(params),
  ),
]);
''';
      final parsed = RouteTypegen.parseSource(source);
      expect(parsed.length, 1);
      expect(parsed.first.path, '/admin/products/:id');
      expect(parsed.first.params, ['id']);
    });

    test('merges secondary filesystem routes without duplicate paths', () {
      final primary = [
        const ParsedRoute(path: '/', params: [], hasWildcard: false),
        const ParsedRoute(path: '/cart', params: [], hasWildcard: false),
      ];

      final secondary = [
        const DiscoveredRoute(
          relativeFilePath: 'cart.dart',
          routePath: '/cart',
          componentClassName: 'CartRoute',
        ),
        const DiscoveredRoute(
          relativeFilePath: 'settings.dart',
          routePath: '/settings',
          componentClassName: 'SettingsRoute',
        ),
      ];

      final secParsed = RouteTypegen.fromDiscoveredRoutes(secondary);
      final merged = RouteTypegen.mergeRoutes(primary, secParsed);

      expect(merged.length, 3);
      expect(merged.map((r) => r.path).toList(), ['/', '/cart', '/settings']);
    });
  });

  group('RouteTypegen Code Generator', () {
    test('generates static const route strings', () {
      final routes = [
        const ParsedRoute(path: '/', params: [], hasWildcard: false),
        const ParsedRoute(path: '/cart', params: [], hasWildcard: false),
        const ParsedRoute(path: '/admin/products/new', params: [], hasWildcard: false),
      ];

      final result = RouteTypegen.generate(routes: routes);
      expect(result.symbols.length, 3);

      expect(result.symbols[0].identifier, 'routeHome');
      expect(result.symbols[0].isConst, isTrue);
      expect(result.symbols[0].declarationCode, "const String routeHome = '/';");

      expect(result.symbols[1].identifier, 'routeCart');
      expect(result.symbols[1].isConst, isTrue);
      expect(result.symbols[1].declarationCode, "const String routeCart = '/cart';");

      expect(result.symbols[2].identifier, 'routeAdminProductsNew');
      expect(result.symbols[2].isConst, isTrue);
      expect(
        result.symbols[2].declarationCode,
        "const String routeAdminProductsNew = '/admin/products/new';",
      );
    });

    test('generates parameterized route functions', () {
      final routes = [
        const ParsedRoute(path: '/p/:slug', params: ['slug'], hasWildcard: false),
        const ParsedRoute(
          path: '/admin/products/:id',
          params: ['id'],
          hasWildcard: false,
        ),
        const ParsedRoute(
          path: '/users/:userId/posts/:postId',
          params: ['userId', 'postId'],
          hasWildcard: false,
        ),
      ];

      final result = RouteTypegen.generate(routes: routes);
      expect(result.symbols.length, 3);

      expect(result.symbols[0].identifier, 'routePBySlug');
      expect(result.symbols[0].isConst, isFalse);
      expect(
        result.symbols[0].declarationCode,
        "String routePBySlug({required String slug}) => '/p/\$slug';",
      );

      expect(result.symbols[1].identifier, 'routeAdminProductsById');
      expect(result.symbols[1].isConst, isFalse);
      expect(
        result.symbols[1].declarationCode,
        "String routeAdminProductsById({required String id}) => '/admin/products/\$id';",
      );

      expect(result.symbols[2].identifier, 'routeUsersPostsByUserIdAndPostId');
      expect(result.symbols[2].isConst, isFalse);
      expect(
        result.symbols[2].declarationCode,
        "String routeUsersPostsByUserIdAndPostId({\n  required String userId,\n  required String postId,\n}) => '/users/\$userId/posts/\$postId';",
      );
    });

    test('generates wildcard route functions', () {
      final routes = [
        const ParsedRoute(path: '/docs/*', params: [], hasWildcard: true),
      ];

      final result = RouteTypegen.generate(routes: routes);
      expect(result.symbols.length, 1);
      expect(result.symbols[0].identifier, 'routeDocs');
      expect(
        result.symbols[0].declarationCode,
        "String routeDocs({required String rest}) => '/docs/\$rest';",
      );
    });

    test('handles collisions with numerical suffixes', () {
      final routes = [
        const ParsedRoute(path: '/admin-products', params: [], hasWildcard: false),
        const ParsedRoute(path: '/admin/products', params: [], hasWildcard: false),
      ];

      final warnings = <String>[];
      final result = RouteTypegen.generate(
        routes: routes,
        onWarning: (w) => warnings.add(w),
      );

      expect(result.symbols.length, 2);
      expect(result.symbols[0].identifier, 'routeAdminProducts');
      expect(result.symbols[1].identifier, 'routeAdminProducts2');
      expect(warnings.length, 1);
      expect(warnings.first, contains('Naming collision'));
    });
  });

  group('Real-World Ground Truth: benchmarks/marketplace/bloom/lib/main.dart', () {
    test('parses and generates typed routes for all marketplace routes', () {
      const marketplaceFixture = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;
import 'components/dialog.dart';
import 'components/toast.dart';
import 'pages/admin.dart';
import 'pages/cart.dart';
import 'pages/storefront.dart';

String _resolveApiBaseUrl() {
  final env = BloomEnv.getOrNull('API_BASE_URL') ?? BloomEnv.getOrNull('API_URL');
  if (env != null && env.isNotEmpty) return env;
  try {
    final origin = web.window.location.origin;
    if (origin.isNotEmpty && origin != 'null') return origin;
  } catch (_) {}
  return 'http://localhost:3000';
}

final BloomHttpClient httpClient = BloomHttpClient(baseUrl: _resolveApiBaseUrl());

late final BloomRouterController routerController = BloomRouterController(BloomRouter([
  BloomRoute('/', (params) => homePage(params)),
  BloomRoute('/cart', (params) => cartPage(params)),
  BloomRoute('/p/:slug', (params) => productDetailPage(params)),
  BloomRoute('/c/:slug', (params) => categoryPage(params)),
  BloomRoute('/admin', (params) => adminDashboard(params)),
  BloomRoute('/admin/products', (params) => adminProducts(params)),
  BloomRoute('/admin/products/new', (params) => adminProductNew(params)),
  BloomRoute('/admin/products/:id', (params) => adminProductForm(params)),
], notFound: BloomRoute('/', (params) => homePage(params))));

void main() {
  mount(
    Fragment(children: [
      Live(() => routerController.resolve()),
      dialogViewport(),
      toastViewport(),
    ]),
    '#app',
  );
}
''';

      final candidatePath = p.normalize(
        p.join(
          Directory.current.path,
          '..',
          '..',
          'benchmarks',
          'marketplace',
          'bloom',
          'lib',
          'main.dart',
        ),
      );
      final file = File(candidatePath);
      final source = file.existsSync() ? file.readAsStringSync() : marketplaceFixture;

      final parsed = RouteTypegen.parseSource(source);
      expect(parsed.length, 8);

      final result = RouteTypegen.generate(
        routes: parsed,
        entryPath: 'benchmarks/marketplace/bloom/lib/main.dart',
      );

      expect(result.symbols.length, 8);

      final expected = <String, String>{
        '/': 'routeHome',
        '/cart': 'routeCart',
        '/p/:slug': 'routePBySlug',
        '/c/:slug': 'routeCBySlug',
        '/admin': 'routeAdmin',
        '/admin/products': 'routeAdminProducts',
        '/admin/products/new': 'routeAdminProductsNew',
        '/admin/products/:id': 'routeAdminProductsById',
      };

      for (final sym in result.symbols) {
        expect(expected[sym.route.path], sym.identifier);
      }

      // Assert zero collisions in real marketplace app
      final identifiers = result.symbols.map((s) => s.identifier).toSet();
      expect(identifiers.length, 8);

      // Verify generated code output contains expected declarations
      expect(result.code, contains("const String routeHome = '/';"));
      expect(result.code, contains("const String routeCart = '/cart';"));
      expect(result.code, contains("String routePBySlug({required String slug}) => '/p/\$slug';"));
      expect(result.code, contains("String routeCBySlug({required String slug}) => '/c/\$slug';"));
      expect(result.code, contains("const String routeAdmin = '/admin';"));
      expect(result.code, contains("const String routeAdminProducts = '/admin/products';"));
      expect(result.code, contains("const String routeAdminProductsNew = '/admin/products/new';"));
      expect(result.code, contains("String routeAdminProductsById({required String id}) => '/admin/products/\$id';"));
    });
  });
}
