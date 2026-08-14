// test/bloom_phase15_tooling_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/module_command.dart';
import 'package:bloom_cli/src/commands/templates_command.dart';
import 'package:bloom_cli/src/templates/template_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_phase15_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Directory _createMockModule(Directory parentDir, {String name = 'bloom_sensor', bool withFailingTest = false}) {
    final moduleDir = Directory(p.join(parentDir.path, name))..createSync(recursive: true);

    File(p.join(moduleDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: $name
description: Bloom Sensor Native Module
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.27.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  test: ^1.25.0
''');

    File(p.join(moduleDir.path, 'bloom.yaml')).writeAsStringSync('''
name: $name
version: 1.0.0
type: module
''');

    final libDir = Directory(p.join(moduleDir.path, 'lib'))..createSync(recursive: true);
    File(p.join(libDir.path, '$name.dart')).writeAsStringSync('''
class BloomSensor {
  static int readLevel() => 42;
}
''');

    final testDir = Directory(p.join(moduleDir.path, 'test'))..createSync(recursive: true);
    if (withFailingTest) {
      File(p.join(testDir.path, '${name}_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:$name/$name.dart';

void main() {
  test('failing test', () {
    expect(BloomSensor.readLevel(), equals(999));
  });
}
''');
    } else {
      File(p.join(testDir.path, '${name}_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:$name/$name.dart';

void main() {
  test('passing test', () {
    expect(BloomSensor.readLevel(), equals(42));
  });
}
''');
    }

    return moduleDir;
  }

  group('Phase 15: Starter Templates Registry (bloom templates)', () {
    test('Lists all official starter templates with categories and features', () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(TemplatesCommand());

      final exitCode = await runner.run(['templates']);
      expect(exitCode, 0);

      final templates = TemplateRegistry.officialTemplates;
      expect(templates.length, greaterThanOrEqualTo(5));
      expect(templates.any((t) => t.name == 'ecommerce'), isTrue);
      expect(templates.any((t) => t.name == 'social'), isTrue);
      expect(templates.any((t) => t.name == 'fullstack'), isTrue);
      expect(templates.any((t) => t.name == 'minimal'), isTrue);
    });

    test('Outputs valid JSON list when --json flag is provided', () async {
      final templates = TemplateRegistry.officialTemplates;
      final jsonStr = const JsonEncoder.withIndent('  ').convert(templates.map((t) => {
            'name': t.name,
            'description': t.description,
            'category': t.category,
            'features': t.includedFeatures,
          }).toList());

      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, templates.length);
      expect(decoded.first['name'], 'default');
    });
  });

  group('Phase 15: Bloom Module Sandbox & Test Harness (C3, C4)', () {
    test('bloom module dev generates minimal host app in .bloom/sandbox/ (C4)', () async {
      final moduleDir = _createMockModule(tempDir, name: 'bloom_test_module');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(ModuleCommand());

      final exitCode = await runner.run(['module', 'dev', '--module-dir', moduleDir.path, '--dry-run']);
      expect(exitCode, 0);

      final sandboxDir = Directory(p.join(moduleDir.path, '.bloom', 'sandbox'));
      expect(sandboxDir.existsSync(), isTrue);

      final hostPubspec = File(p.join(sandboxDir.path, 'pubspec.yaml'));
      expect(hostPubspec.existsSync(), isTrue);
      final pubspecContent = hostPubspec.readAsStringSync();
      expect(pubspecContent, contains('bloom_test_module:'));
      expect(pubspecContent, contains('path: ../..'));

      final hostMain = File(p.join(sandboxDir.path, 'lib', 'main.dart'));
      expect(hostMain.existsSync(), isTrue);
      final mainContent = hostMain.readAsStringSync();
      expect(mainContent, contains('Bloom Module Sandbox: bloom_test_module'));
    });

    test('bloom module test executes test suites and returns non-zero on failure (C3)', () async {
      final failingModule = _createMockModule(tempDir, name: 'failing_sensor', withFailingTest: true);

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(ModuleCommand());

      final exitCode = await runner.run(['module', 'test', '--module-dir', failingModule.path]);
      expect(exitCode, 1);
    });
  });
}
