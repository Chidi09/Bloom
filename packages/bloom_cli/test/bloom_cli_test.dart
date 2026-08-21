// test/bloom_cli_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/npm/npm_resolver.dart';
import '../lib/src/templates/templates.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('CLI Templates', () {
    test('bloom.yaml template generates valid manifest', () {
      final yaml = BloomTemplates.bloomYaml(name: 'test_app');
      expect(yaml.contains('name: test_app'), true);
      expect(yaml.contains('schema: 1'), true);
      expect(yaml.contains('features:'), true);
    });

    test('dotEnv template generates environment variables', () {
      final env = BloomTemplates.dotEnv(name: 'test_app');
      expect(env.contains('APP_NAME=test_app'), true);
      expect(env.contains('APP_ENV=development'), true);
    });

    test('mainDart template includes Bloom.boot() and BloomApp', () {
      final mainCode = BloomTemplates.mainDart(projectName: 'test_app');
      expect(mainCode.contains('await Bloom.boot('), true);
      expect(mainCode.contains('BloomApp('), true);
      expect(mainCode.contains('routerConfig: appRouter'), true);
    });

    test('generatedRouter generates typed GoRouter configuration', () {
      final routes = [
        const DiscoveredRoute(
          relativeFilePath: 'index.dart',
          routePath: '/',
          componentClassName: 'IndexRoute',
          isIndex: true,
        ),
        const DiscoveredRoute(
          relativeFilePath: 'users/index.dart',
          routePath: '/users',
          componentClassName: 'UsersIndexRoute',
        ),
        const DiscoveredRoute(
          relativeFilePath: 'users/[id].dart',
          routePath: '/users/:id',
          componentClassName: 'UsersIdRoute',
          isParameterized: true,
          parameters: ['id'],
        ),
      ];

      final code = BloomTemplates.generatedRouter(
        projectName: 'test_app',
        routes: routes,
      );

      expect(code.contains("import '../routes/index.dart';"), true);
      expect(code.contains("import '../routes/users/index.dart';"), true);
      expect(code.contains("import '../routes/users/[id].dart';"), true);
      expect(code.contains("path: '/'"), true);
      expect(code.contains("path: '/users'"), true);
      expect(code.contains("path: '/users/:id'"), true);
      expect(code.contains('final GoRouter appRouter = BloomRouter.create('), true);
    });
  });

  group('Filesystem Route Scanner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_test_');
      final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes'));
      routesDir.createSync(recursive: true);

      // Create test route files
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('// index');
      File(p.join(routesDir.path, 'about.dart')).writeAsStringSync('// about');
      
      final usersDir = Directory(p.join(routesDir.path, 'users'));
      usersDir.createSync();
      File(p.join(usersDir.path, 'index.dart')).writeAsStringSync('// users index');
      File(p.join(usersDir.path, '[id].dart')).writeAsStringSync('// user detail');

      // Create bloom.yaml and pubspec.yaml
      File(p.join(tempDir.path, 'bloom.yaml')).writeAsStringSync('name: temp_test');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: temp_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('scans and correctly maps filesystem routes', () {
      final project = BloomProject(
        rootDir: tempDir,
        bloomYamlFile: File(p.join(tempDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(tempDir.path, 'pubspec.yaml')),
      );

      final routes = project.scanRoutes();
      final paths = routes.map((r) => r.routePath).toList();

      expect(paths.contains('/'), true);
      expect(paths.contains('/about'), true);
      expect(paths.contains('/users'), true);
      expect(paths.contains('/users/:id'), true);
    });
  });

  group('NPM Dynamic Resolver', () {
    test('resolves live package metadata from NPM registry', () async {
      final resolver = NpmResolver();
      final meta = await resolver.fetchPackageMetadata('dayjs');
      expect(meta, isNotNull);
      expect(meta!.name, equals('dayjs'));
      expect(meta.version, isNotEmpty);
      expect(meta.description, isNotEmpty);
    });

    test('searches live NPM registry for packages', () async {
      final resolver = NpmResolver();
      final results = await resolver.search('chart', limit: 5);
      expect(results, isNotEmpty);
      expect(results.first.name, isNotEmpty);
    });
  });
}
