import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/build_command.dart';
import '../lib/src/utils/project.dart';
import '../lib/src/web/prerender_engine.dart';
import '../lib/src/web/ssg_engine.dart';
import '../lib/src/web/ssr_engine.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_prerender_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Headless Prerendering Architecture & Build Command Verification', () {
    test('BuildCommand executes "flutter build web --release" before SSG/SSR generation', () async {
      final appDir = Directory(p.join(tempDir.path, 'flutter_build_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: flutter_build_app\n');
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class Index {}\n');

      final executedCommands = <List<String>>[];

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (executable, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            executedCommands.add([executable, ...args]);
            return ProcessResult(1234, 0, 'Flutter web build completed', '');
          },
        ));

      final exitCode = await runner.run([
        'build',
        'web',
        '--static',
        '--project-dir=${appDir.path}',
      ]);

      expect(exitCode, 0);
      expect(executedCommands.length, 1);
      expect(executedCommands.first, ['flutter', 'build', 'web', '--release']);
    });

    test('BuildCommand halts and returns 1 if "flutter build web --release" fails', () async {
      final appDir = Directory(p.join(tempDir.path, 'flutter_fail_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: flutter_fail_app\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (executable, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            return ProcessResult(1234, 1, '', 'Compilation error in main.dart');
          },
        ));

      final exitCode = await runner.run([
        'build',
        'web',
        '--static',
        '--project-dir=${appDir.path}',
      ]);

      expect(exitCode, 1);
      // Ensure build/web was not generated
      final indexHtml = File(p.join(appDir.path, 'build', 'web', 'index.html'));
      expect(indexHtml.existsSync(), isFalse);
    });

    test('BloomPrerenderEngine returns null safely when browser is uninitialized', () async {
      final engine = BloomPrerenderEngine();
      // Without calling start, browser is null
      final result = await engine.renderRoute('/test');
      expect(result, isNull);
      await engine.close();
    });

    test('BloomSsgEngine falls back gracefully to template when Chromium is unavailable', () async {
      final appDir = Directory(p.join(tempDir.path, 'ssg_fallback_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: ssg_fallback_app\n');
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'about.dart')).writeAsStringSync("const title = 'About Fallback';\nclass About {}\n");

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final ssg = BloomSsgEngine(project: project);
      await ssg.generate();

      final aboutHtml = File(p.join(appDir.path, 'build', 'web', 'about', 'index.html'));
      expect(aboutHtml.existsSync(), isTrue);
      final content = aboutHtml.readAsStringSync();
      expect(content, contains('<title>About Fallback</title>'));
      expect(content, contains('id="bloom-app-root"'));
    });

    test('BloomSsrEngine emits /__bloom_shell route and prerender-enabled SSR server code', () async {
      final appDir = Directory(p.join(tempDir.path, 'ssr_prerender_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: ssr_prerender_app\n');
      final routesDir = Directory(p.join(appDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'dashboard.dart')).writeAsStringSync('''
import 'package:bloom_framework/bloom.dart';

@BloomLoader(revalidate: Duration(seconds: 30))
Future<Map<String, dynamic>> loadDashboard(BloomRouteContext ctx) async => {'status': 'ok'};
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

      // Check imports
      expect(serverCode, contains("import 'package:bloom_cli/src/web/prerender_engine.dart';"));

      // Check single browser instance creation at startup
      expect(serverCode, contains("final _prerenderEngine = BloomPrerenderEngine();"));
      expect(serverCode, contains("await _prerenderEngine.startWithExistingServer('http://localhost:\$port');"));

      // Check neutral /__bloom_shell route registration
      expect(serverCode, contains("router.get('/__bloom_shell', (req) async {"));
      expect(serverCode, contains("window.__BLOOM_INITIAL_ROUTE__ ="));

      // Check prerenderRoute call on page routes & ISR
      expect(serverCode, contains("await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path))"));
      expect(serverCode, contains("prerenderedBodyHtml: prerendered"));

      // Check _renderDynamicSsrHtml accepts prerenderedBodyHtml and handles fallback
      expect(serverCode, contains("String? prerenderedBodyHtml"));
      expect(serverCode, contains(r'prerenderedBodyHtml != null'));
    });
  });
}
