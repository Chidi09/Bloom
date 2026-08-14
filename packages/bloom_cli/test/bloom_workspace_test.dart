// test/bloom_workspace_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import '../lib/src/commands/workspace_command.dart';
import '../lib/src/native/workspace_manager.dart';

void main() {
  late Directory tempDir;
  final rootDir = Directory.current;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_workspace_test_');
  });

  tearDown(() {
    Directory.current = rootDir;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 10: Monorepos & Workspace Manager (bloom workspace)', () {
    test('Discovers apps, packages, and native modules in monorepo', () async {
      // 1. Create workspace structure
      final appDir = Directory(p.join(tempDir.path, 'apps', 'storefront'))..createSync(recursive: true);
      final pkgDir = Directory(p.join(tempDir.path, 'packages', 'shared_ui'))..createSync(recursive: true);
      final modDir = Directory(p.join(tempDir.path, 'modules', 'barcode_scanner'))..createSync(recursive: true);

      // App files
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: storefront
version: 2.0.0
dependencies:
  shared_ui:
    path: ../../packages/shared_ui
''');
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: storefront\n');

      // Package files
      File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: shared_ui
version: 1.5.0
''');

      // Native module files
      File(p.join(modDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: barcode_scanner
version: 1.0.0
''');
      File(p.join(modDir.path, 'bloom.module.yaml')).writeAsStringSync('''
name: barcode_scanner
version: 1.0.0
''');

      final manager = BloomWorkspaceManager(tempDir);
      final projects = manager.discoverProjects();

      expect(projects.length, 3);
      final names = projects.map((p) => p.name).toSet();
      expect(names, containsAll(['storefront', 'shared_ui', 'barcode_scanner']));

      final types = {for (var p in projects) p.name: p.type};
      expect(types['storefront'], WorkspaceProjectType.app);
      expect(types['shared_ui'], WorkspaceProjectType.package);
      expect(types['barcode_scanner'], WorkspaceProjectType.nativeModule);

      // 2. Test CLI command bloom workspace status
      final prevDir = Directory.current;
      Directory.current = tempDir;

      try {
        final runner = CommandRunner<int>('bloom', 'Bloom CLI')
          ..addCommand(WorkspaceCommand());

        final statusCode = await runner.run(['workspace', 'status']);
        expect(statusCode, 0);

        final depsCode = await runner.run(['workspace', 'deps']);
        expect(depsCode, 0);
      } finally {
        Directory.current = prevDir;
      }
    });
  });
}
