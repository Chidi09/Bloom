// test/typegen_command_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/commands/typegen_command.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_typegen_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  void _createMockProject(Directory dir, {String? mainContent}) {
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_typegen_app
description: Test Bloom Typegen Project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

    File(p.join(dir.path, 'bloom.yaml')).writeAsStringSync('''
name: test_typegen_app
version: 1.0.0
mode: managed
''');

    final libDir = Directory(p.join(dir.path, 'lib'))..createSync(recursive: true);
    final content = mainContent ??
        '''
import 'package:bloom_js_native/bloom_js_native.dart';

final router = BloomRouter([
  BloomRoute('/', (params) => home(params)),
  BloomRoute('/cart', (params) => cart(params)),
  BloomRoute('/p/:slug', (params) => product(params)),
  BloomRoute('/admin/products/:id', (params) => adminProduct(params)),
]);
''';
    File(p.join(libDir.path, 'main.dart')).writeAsStringSync(content);
  }

  group('TypegenCommand CLI', () {
    test('generates typed routes file for a valid project', () async {
      _createMockProject(tempDir);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
      ]);

      expect(exitCode, 0);

      final generatedFile = File(
        p.join(tempDir.path, 'lib', 'generated', 'routes.g.dart'),
      );
      expect(generatedFile.existsSync(), isTrue);

      final content = generatedFile.readAsStringSync();
      expect(content, contains('// GENERATED FILE — DO NOT EDIT BY HAND.'));
      expect(content, contains("const String routeHome = '/';"));
      expect(content, contains("const String routeCart = '/cart';"));
      expect(
        content,
        contains("String routePBySlug({required String slug}) => '/p/\$slug';"),
      );
      expect(
        content,
        contains(
          "String routeAdminProductsById({required String id}) => '/admin/products/\$id';",
        ),
      );
    });

    test('supports custom --entry and --out parameters', () async {
      _createMockProject(tempDir);

      final customEntry = File(p.join(tempDir.path, 'lib', 'routes_manifest.dart'));
      customEntry.writeAsStringSync('''
final appRoutes = [
  BloomRoute('/dashboard', (params) => dashboard(params)),
  BloomRoute('/items/:itemId', (params) => item(params)),
];
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
        '--entry',
        'lib/routes_manifest.dart',
        '--out',
        'lib/src/routes.dart',
      ]);

      expect(exitCode, 0);

      final generatedFile = File(p.join(tempDir.path, 'lib', 'src', 'routes.dart'));
      expect(generatedFile.existsSync(), isTrue);

      final content = generatedFile.readAsStringSync();
      expect(content, contains("const String routeDashboard = '/dashboard';"));
      expect(
        content,
        contains("String routeItemsByItemId({required String itemId}) => '/items/\$itemId';"),
      );
    });

    test('returns 1 when directory is not a Bloom project', () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
      ]);

      expect(exitCode, 1);
    });

    test('returns 1 when entry file does not exist', () async {
      _createMockProject(tempDir);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
        '--entry',
        'lib/non_existent.dart',
      ]);

      expect(exitCode, 1);
    });

    test('returns 0 when entry file contains no routes', () async {
      _createMockProject(
        tempDir,
        mainContent: '''
void main() {
  print("No routes here");
}
''',
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
      ]);

      expect(exitCode, 0);
    });

    test('merges secondary routes from lib/routes/ if present', () async {
      _createMockProject(tempDir);

      final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes', 'settings'))
        ..createSync(recursive: true);
      File(p.join(routesDir.path, 'profile.dart')).writeAsStringSync('''
class ProfileRoute {}
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TypegenCommand());

      final exitCode = await runner.run([
        'typegen',
        '--project-dir',
        tempDir.path,
      ]);

      expect(exitCode, 0);

      final generatedFile = File(
        p.join(tempDir.path, 'lib', 'generated', 'routes.g.dart'),
      );
      final content = generatedFile.readAsStringSync();
      expect(content, contains("const String routeSettingsProfile = '/settings/profile';"));
    });
  });
}
