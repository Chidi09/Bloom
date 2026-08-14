// test/bloom_symbols_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/symbols_command.dart';
import '../lib/src/symbolication/symbol_packager.dart';
import '../lib/src/utils/project.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_symbols_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 13: BloomSymbolPackager & Symbolication Manifest', () {
    test('Discovers Android ProGuard, iOS dSYM, and Web source maps and writes manifest', () async {
      final appDir = Directory(p.join(tempDir.path, 'symbol_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: symbol_app
version: 1.5.0
build_number: "42"
''');

      // 1. Mock Android mapping.txt
      final mappingDir = Directory(p.join(appDir.path, 'android', 'app', 'build', 'outputs', 'mapping', 'release'))
        ..createSync(recursive: true);
      File(p.join(mappingDir.path, 'mapping.txt')).writeAsStringSync('com.example.App -> a.b.c:\n');

      // 2. Mock iOS dSYM bundle
      final dsymDir = Directory(p.join(appDir.path, 'build', 'ios', 'Runner.app.dSYM', 'Contents', 'Resources', 'DWARF'))
        ..createSync(recursive: true);
      File(p.join(dsymDir.path, 'Runner')).writeAsStringSync('DWARF_BINARY_MOCK_DATA');

      // 3. Mock Web source map
      final webDir = Directory(p.join(appDir.path, 'build', 'web'))..createSync(recursive: true);
      File(p.join(webDir.path, 'main.dart.js.map')).writeAsStringSync('{"version":3,"sources":[]}');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final packager = BloomSymbolPackager(project: project);
      final symbols = packager.discoverSymbols();

      expect(symbols.length, 3);
      expect(symbols.any((s) => s.platform == 'android' && s.type == 'proguard'), isTrue);
      expect(symbols.any((s) => s.platform == 'ios' && s.type == 'dsym'), isTrue);
      expect(symbols.any((s) => s.platform == 'web' && s.type == 'sourcemap'), isTrue);

      final manifestFile = await packager.packageSymbols();
      expect(manifestFile.existsSync(), isTrue);

      final manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifestJson['appName'], 'symbol_app');
      expect(manifestJson['version'], '1.5.0');
      expect(manifestJson['buildNumber'], '42');
      expect((manifestJson['artifacts'] as List).length, 3);
    });
  });

  group('Phase 13: CLI SymbolsCommand Execution', () {
    test('bloom symbols package and bloom symbols upload execute cleanly', () async {
      final appDir = Directory(p.join(tempDir.path, 'cli_symbols_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: cli_symbols_app\nversion: 1.0.0\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(SymbolsCommand());

      final packageExit = await runner.run([
        'symbols',
        'package',
        '--project-dir=${appDir.path}',
      ]);
      expect(packageExit, 0);

      final uploadExit = await runner.run([
        'symbols',
        'upload',
        '--project-dir=${appDir.path}',
      ]);
      expect(uploadExit, 0);
    });
  });
}
