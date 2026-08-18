import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/build_command.dart';
import '../lib/src/utils/project.dart';
import '../lib/src/web/ssr_engine.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_isr_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Incremental Static Regeneration (ISR) Discovery', () {
    test('BloomSsrEngine correctly parses Duration units and values from @BloomLoader', () async {
      final appDir = Directory(p.join(tempDir.path, 'isr_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: isr_app\n');

      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);

      // 1. Seconds revalidation
      File(p.join(routesDir.path, 'products.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(seconds: 60))
Future<Map<String, dynamic>> loadProducts(BloomRouteContext context) async {
  return {'items': ['laptop', 'phone']};
}
''');

      // 2. Minutes revalidation
      File(p.join(routesDir.path, 'news.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(minutes: 5))
Future<Map<String, dynamic>> loadNews(BloomRouteContext context) async {
  return {'headlines': ['Bloom 1.0 Released']};
}
''');

      // 3. Hours revalidation
      File(p.join(routesDir.path, 'analytics.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(hours: 2))
Future<Map<String, dynamic>> loadAnalytics(BloomRouteContext context) async {
  return {'visitors': 1000};
}
''');

      // 4. Days revalidation
      File(p.join(routesDir.path, 'archive.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(days: 7))
Future<Map<String, dynamic>> loadArchive(BloomRouteContext context) async {
  return {'archived': true};
}
''');

      // 5. const Duration revalidation
      File(p.join(routesDir.path, 'const_page.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: const Duration(seconds: 30))
Future<Map<String, dynamic>> loadConst(BloomRouteContext context) async {
  return {'const': true};
}
''');

      // 6. Multi-line Duration revalidation
      File(p.join(routesDir.path, 'multiline.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(
  revalidate: Duration(
    seconds: 120,
  ),
)
Future<Map<String, dynamic>> loadMultiline(BloomRouteContext context) async {
  return {'multiline': true};
}
''');

      // 7. Standard loader without revalidate (pure SSR)
      File(p.join(routesDir.path, 'live.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader()
Future<Map<String, dynamic>> loadLive(BloomRouteContext context) async {
  return {'time': DateTime.now().toIso8601String()};
}
''');

      // 8. Static page without loader
      File(p.join(routesDir.path, 'about.dart')).writeAsStringSync('''
const title = 'About Us';
class AboutRoute {}
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssr = BloomSsrEngine(project: project);
      final pageRoutes = ssr.discoverPageRoutes();

      final productsRoute = pageRoutes.firstWhere((r) => r.path == '/products');
      expect(productsRoute.hasLoader, isTrue);
      expect(productsRoute.loaderFunctionName, 'loadProducts');
      expect(productsRoute.revalidate, equals(const Duration(seconds: 60)));

      final newsRoute = pageRoutes.firstWhere((r) => r.path == '/news');
      expect(newsRoute.hasLoader, isTrue);
      expect(newsRoute.loaderFunctionName, 'loadNews');
      expect(newsRoute.revalidate, equals(const Duration(minutes: 5)));

      final analyticsRoute = pageRoutes.firstWhere((r) => r.path == '/analytics');
      expect(analyticsRoute.hasLoader, isTrue);
      expect(analyticsRoute.loaderFunctionName, 'loadAnalytics');
      expect(analyticsRoute.revalidate, equals(const Duration(hours: 2)));

      final archiveRoute = pageRoutes.firstWhere((r) => r.path == '/archive');
      expect(archiveRoute.hasLoader, isTrue);
      expect(archiveRoute.loaderFunctionName, 'loadArchive');
      expect(archiveRoute.revalidate, equals(const Duration(days: 7)));

      final constRoute = pageRoutes.firstWhere((r) => r.path == '/const_page');
      expect(constRoute.hasLoader, isTrue);
      expect(constRoute.loaderFunctionName, 'loadConst');
      expect(constRoute.revalidate, equals(const Duration(seconds: 30)));

      final multilineRoute = pageRoutes.firstWhere((r) => r.path == '/multiline');
      expect(multilineRoute.hasLoader, isTrue);
      expect(multilineRoute.loaderFunctionName, 'loadMultiline');
      expect(multilineRoute.revalidate, equals(const Duration(seconds: 120)));

      final liveRoute = pageRoutes.firstWhere((r) => r.path == '/live');
      expect(liveRoute.hasLoader, isTrue);
      expect(liveRoute.loaderFunctionName, 'loadLive');
      expect(liveRoute.revalidate, isNull);

      final aboutRoute = pageRoutes.firstWhere((r) => r.path == '/about');
      expect(aboutRoute.hasLoader, isFalse);
      expect(aboutRoute.revalidate, isNull);
    });
  });

  group('Incremental Static Regeneration (ISR) Code Generation', () {
    test('BloomSsrEngine generates ISR cache infrastructure and per-route caching handlers', () async {
      final appDir = Directory(p.join(tempDir.path, 'isr_gen_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: isr_gen_app
web:
  pwa:
    theme_color: "#10B981"
''');

      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);

      // ISR Route
      File(p.join(routesDir.path, 'products.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(seconds: 45))
Future<Map<String, dynamic>> loadProducts(BloomRouteContext context) async {
  return {'items': ['item1']};
}
''');

      // Non-ISR Loader Route
      File(p.join(routesDir.path, 'profile.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader()
Future<Map<String, dynamic>> loadProfile(BloomRouteContext context) async {
  return {'user': 'alice'};
}
''');

      // Plain static Route
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('''
class IndexPage {}
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssr = BloomSsrEngine(project: project);
      final serverFile = await ssr.generate();
      expect(serverFile.existsSync(), isTrue);

      final serverCode = serverFile.readAsStringSync();

      // Verify top-level ISR cache structures
      expect(serverCode, contains('class _IsrCacheEntry {'));
      expect(serverCode, contains('final String html;'));
      expect(serverCode, contains('final DateTime generatedAt;'));
      expect(serverCode, contains('bool _isRevalidating = false;'));
      expect(serverCode, contains('final Map<String, _IsrCacheEntry> _isrCache = {};'));

      // Verify ISR route handler for /products
      expect(serverCode, contains("router.get('/products', (req) async {"));
      expect(serverCode, contains("final cacheKey = req.path;"));
      expect(serverCode, contains("final cached = _isrCache[cacheKey];"));
      expect(serverCode, contains("DateTime.now().difference(cached.generatedAt) < Duration(seconds: 45)"));
      expect(serverCode, contains("if (!cached._isRevalidating) {"));
      expect(serverCode, contains("cached._isRevalidating = true;"));
      expect(serverCode, contains("loadProducts(ctx)"));
      expect(serverCode, contains("_isrCache[cacheKey] = _IsrCacheEntry(html, DateTime.now());"));
      expect(serverCode, contains("cached._isRevalidating = false;"));

      // Generated route handlers can appear in any filesystem enumeration order,
      // so locate each block by its own start marker and the next "router.get("/
      // "router.all(" occurrence after it, rather than assuming a fixed order.
      String blockStartingAt(String marker) {
        final start = serverCode.indexOf(marker);
        expect(start, greaterThanOrEqualTo(0), reason: 'marker not found: $marker');
        final nextGet = serverCode.indexOf("router.get(", start + marker.length);
        final nextAll = serverCode.indexOf("router.all(", start + marker.length);
        final candidates = [nextGet, nextAll].where((i) => i >= 0);
        final end = candidates.isEmpty ? serverCode.length : candidates.reduce((a, b) => a < b ? a : b);
        return serverCode.substring(start, end);
      }

      // Verify Non-ISR loader route (/profile) does NOT use _isrCache
      final profileBlock = blockStartingAt("router.get('/profile', (req) async {");
      expect(profileBlock, isNot(contains("_isrCache")));
      expect(profileBlock, contains("loadProfile(ctx)"));

      // Verify Static route (/) does NOT use loader or _isrCache
      final indexBlock = blockStartingAt("router.get('/', (req) async {");
      expect(indexBlock, isNot(contains("_isrCache")));
      expect(indexBlock, isNot(contains("BloomRouteContext")));
    });

    test('bloom build web --server builds successfully with ISR routes', () async {
      final appDir = Directory(p.join(tempDir.path, 'build_isr_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: build_isr_app\n');

      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'items.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(minutes: 10))
Future<Map<String, dynamic>> loadItems(BloomRouteContext context) async {
  return {'items': []};
}
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (cmd, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async =>
              ProcessResult(0, 0, 'mock build web success', ''),
        ));

      final exitCode = await runner.run([
        'build',
        'web',
        '--server',
        '--project-dir=${appDir.path}',
      ]);

      expect(exitCode, 0);

      final serverFile = File(p.join(appDir.path, 'build', 'server.dart'));
      expect(serverFile.existsSync(), isTrue);

      final content = serverFile.readAsStringSync();
      expect(content, contains("Duration(seconds: 600)"));
      expect(content, contains("_isrCache"));
    });
  });
}
