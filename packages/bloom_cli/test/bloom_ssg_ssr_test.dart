// test/bloom_ssg_ssr_test.dart
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

  group('Phase 12: Static Site Generation (SSG) & PWA Generator', () {
    test('BloomSsgEngine generates pre-rendered HTML, sitemap.xml, robots.txt, and PWA assets', () async {
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
''');

      // Create client routes
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class IndexRoute {}\n');
      File(p.join(routesDir.path, 'about.dart')).writeAsStringSync('class AboutRoute {}\n');
      File(p.join(routesDir.path, 'pricing.dart')).writeAsStringSync('class PricingRoute {}\n');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssg = BloomSsgEngine(project: project);
      final routes = ssg.discoverRoutes();

      expect(routes.length, 3);
      expect(routes.map((r) => r.path).toList(), ['/', '/about', '/pricing']);

      await ssg.generate();

      // Verify generated HTML pages
      final indexHtml = File(p.join(appDir.path, 'build', 'web', 'index.html'));
      final aboutHtml = File(p.join(appDir.path, 'build', 'web', 'about', 'index.html'));
      final pricingHtml = File(p.join(appDir.path, 'build', 'web', 'pricing', 'index.html'));

      expect(indexHtml.existsSync(), isTrue);
      expect(aboutHtml.existsSync(), isTrue);
      expect(pricingHtml.existsSync(), isTrue);
      expect(indexHtml.readAsStringSync(), contains('<title>web_app - Home</title>'));
      expect(aboutHtml.readAsStringSync(), contains('<title>web_app - about</title>'));

      // Verify Sitemap
      final sitemapFile = File(p.join(appDir.path, 'build', 'web', 'sitemap.xml'));
      expect(sitemapFile.existsSync(), isTrue);
      final sitemapContent = sitemapFile.readAsStringSync();
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/</loc>'));
      expect(sitemapContent, contains('<loc>https://myapp.bloom.dev/about</loc>'));

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

  group('Phase 12: Server-Side Rendering (SSR) & API Route Generator', () {
    test('BloomSsrEngine discovers API routes and generates standalone server.dart', () async {
      final appDir = Directory(p.join(tempDir.path, 'ssr_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: ssr_app\n');

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

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssr = BloomSsrEngine(project: project);
      final apiRoutes = ssr.discoverApiRoutes();

      expect(apiRoutes.length, 2);
      expect(apiRoutes.any((r) => r.path == '/api/users'), isTrue);
      expect(apiRoutes.any((r) => r.path == '/api/users/:id'), isTrue);

      final serverFile = await ssr.generate();
      expect(serverFile.existsSync(), isTrue);

      final serverCode = serverFile.readAsStringSync();
      expect(serverCode, contains("router.get('/api/users'"));
      expect(serverCode, contains("router.post('/api/users'"));
      expect(serverCode, contains("router.get('/api/users/:id'"));
      expect(serverCode, contains("router.delete('/api/users/:id'"));
      expect(serverCode, contains("BloomCorsMiddleware()"));
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
