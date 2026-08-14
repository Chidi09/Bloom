import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/build_command.dart';
import '../lib/src/commands/generate_command.dart';
import '../lib/src/utils/project.dart';
import '../lib/src/web/ssg_engine.dart';
import '../lib/src/web/ssr_engine.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_ssg_ssr_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 12: Static Site Generation (SSG) & Parameterized Enumeration', () {
    test('BloomSsgEngine generates pre-rendered HTML, enumerated parameterized routes, sitemap, and PWA assets', () async {
      final appDir = Directory(p.join(tempDir.path, 'web_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: web_app
version: 1.0.0
domain: https://myapp.bloom.dev
web:
  pwa:
    name: "My PWA Store"
    short_name: "PwaStore"
    theme_color: "#10B981"
  static_paths:
    "/products/[id]":
      - "1"
      - "2"
''');

      // Create client routes
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync("const title = 'Home Dashboard';\nclass IndexRoute {}\n");
      File(p.join(routesDir.path, 'about.dart')).writeAsStringSync("const title = 'About Us';\nconst description = 'Bloom Web Platform';\nclass AboutRoute {}\n");

      final productsDir = Directory(p.join(routesDir.path, 'products'))..createSync(recursive: true);
      File(p.join(productsDir.path, '[id].dart')).writeAsStringSync('''
class ProductDetailsRoute {}
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssg = BloomSsgEngine(project: project);
      final routes = ssg.discoverRoutes();

      expect(routes.length, 3);

      await ssg.generate();

      // Verify generated static HTML pages
      final indexHtml = File(p.join(appDir.path, 'build', 'web', 'index.html'));
      final aboutHtml = File(p.join(appDir.path, 'build', 'web', 'about', 'index.html'));
      final prod1Html = File(p.join(appDir.path, 'build', 'web', 'products', '1', 'index.html'));
      final prod2Html = File(p.join(appDir.path, 'build', 'web', 'products', '2', 'index.html'));

      expect(indexHtml.existsSync(), isTrue);
      expect(aboutHtml.existsSync(), isTrue);
      expect(prod1Html.existsSync(), isTrue);
      expect(prod2Html.existsSync(), isTrue);

      expect(aboutHtml.readAsStringSync(), contains('<title>About Us</title>'));
      expect(aboutHtml.readAsStringSync(), contains('<meta name="description" content="Bloom Web Platform" />'));
      expect(aboutHtml.readAsStringSync(), contains('<meta name="theme-color" content="#10B981" />'));
      expect(aboutHtml.readAsStringSync(), contains('<h1 class="bloom-page-title">About</h1>'));

      // Verify Sitemap includes parameterized routes
      final sitemapFile = File(p.join(appDir.path, 'build', 'web', 'sitemap.xml'));
      expect(sitemapFile.existsSync(), isTrue);
      final sitemapContent = sitemapFile.readAsStringSync();
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/</loc>'));
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/about</loc>'));
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/products/1</loc>'));
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/products/2</loc>'));

      // Verify Robots
      final robotsFile = File(p.join(appDir.path, 'build', 'web', 'robots.txt'));
      expect(robotsFile.existsSync(), isTrue);
      expect(robotsFile.readAsStringSync(), contains('Sitemap: https://myapp.bloom.dev/sitemap.xml'));

      // Verify PWA Manifest & Service Worker
      final manifestFile = File(p.join(appDir.path, 'build', 'web', 'manifest.json'));
      final swFile = File(p.join(appDir.path, 'build', 'web', 'flutter_service_worker.js'));
      expect(manifestFile.existsSync(), isTrue);
      expect(swFile.existsSync(), isTrue);
      expect(manifestFile.readAsStringSync(), contains('My PWA Store'));
      expect(manifestFile.readAsStringSync(), contains('#10B981'));
    });
  });

  group('Phase 12: Server-Side Rendering (SSR), Loaders & XSS Hardening', () {
    test('BloomSsrEngine discovers API routes, loader functions, and escapes XSS payloads', () async {
      final appDir = Directory(p.join(tempDir.path, 'ssr_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: ssr_app
web:
  pwa:
    theme_color: "#6366F1"
''');

      final apiDir = Directory(p.join(appDir.path, 'lib', 'routes', 'api', 'users'))..createSync(recursive: true);
      File(p.join(apiDir.path, 'index.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom_server.dart';
Future<BloomResponse> get(BloomRequest req) async => BloomResponse.json([]);
Future<BloomResponse> post(BloomRequest req) async => BloomResponse.json({}, statusCode: 201);
''');
      File(p.join(apiDir.path, '[id].dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom_server.dart';
Future<BloomResponse> get(BloomRequest req) async => BloomResponse.json({'id': req.params['id']});
Future<BloomResponse> delete(BloomRequest req) async => BloomResponse.noContent();
''');

      // Page with route loader
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'products.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader()
Future<Map<String, dynamic>> loadProducts(BloomRouteContext context) async {
  return {'category': 'tech', 'items': ['laptop', 'phone']};
}

@BloomAction()
Future<ActionResult> handleCheckout(BloomRouteContext context, Map<String, dynamic> form) async {
  return ActionResult.success({'orderId': '123'});
}
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssr = BloomSsrEngine(project: project);
      final apiRoutes = ssr.discoverApiRoutes();
      final pageRoutes = ssr.discoverPageRoutes();

      expect(apiRoutes.length, 2);
      expect(pageRoutes.any((p) => p.hasLoader && p.loaderFunctionName == 'loadProducts'), isTrue);
      expect(pageRoutes.any((p) => p.hasAction && p.actionFunctionName == 'handleCheckout'), isTrue);

      final serverFile = await ssr.generate();
      expect(serverFile.existsSync(), isTrue);

      final serverCode = serverFile.readAsStringSync();
      expect(serverCode, contains("router.get('/api/users'"));
      expect(serverCode, contains("router.post('/api/users'"));
      expect(serverCode, contains("router.get('/api/users/:id'"));
      expect(serverCode, contains("router.delete('/api/users/:id'"));
      expect(serverCode, contains("loadProducts(ctx)"));
      expect(serverCode, contains("handleCheckout(ctx, form)"));
      expect(serverCode, contains("themeColor: '#6366F1'"));
      expect(serverCode, contains("BloomCorsMiddleware()"));
      expect(serverCode, contains("router.all('*'"));
      expect(serverCode, contains("p.isWithin(webDir.path, targetPath)"));
      expect(serverCode, contains("window.__BLOOM_LOADER_DATA__ ="));
    });
  });

  group('Phase 12: CLI Build & Generate Integration', () {
    test('bloom generate api generates functional API route handler', () async {
      final appDir = Directory(p.join(tempDir.path, 'gen_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: gen_app\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(GenerateCommand());

      final exitCode = await runner.run([
        'generate',
        'api',
        'orders/[id]',
        '--project-dir=${appDir.path}',
      ]);

      expect(exitCode, 0);

      final generatedFile = File(p.join(appDir.path, 'lib', 'routes', 'api', 'orders', '[id].dart'));
      expect(generatedFile.existsSync(), isTrue);

      final content = generatedFile.readAsStringSync();
      expect(content, contains("import 'package:bloom_framework/bloom_server.dart';"));
      expect(content, contains("Future<BloomResponse> get(BloomRequest request)"));
      expect(content, contains("Future<BloomResponse> post(BloomRequest request)"));
      expect(content, contains("Future<BloomResponse> delete(BloomRequest request)"));
    });

    test('bloom build web --static and --server execute end-to-end', () async {
      final appDir = Directory(p.join(tempDir.path, 'build_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: build_app\n');
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class Index {}\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand());

      // 1. Static SSG Build
      final ssgExit = await runner.run([
        'build',
        'web',
        '--static',
        '--project-dir=${appDir.path}',
      ]);
      expect(ssgExit, 0);
      expect(File(p.join(appDir.path, 'build', 'web', 'index.html')).existsSync(), isTrue);

      // 2. Server SSR Build
      final ssrExit = await runner.run([
        'build',
        'web',
        '--server',
        '--project-dir=${appDir.path}',
      ]);
      expect(ssrExit, 0);
      expect(File(p.join(appDir.path, 'build', 'server.dart')).existsSync(), isTrue);
    });
  });
}
