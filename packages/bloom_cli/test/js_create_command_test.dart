import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/commands/js_command.dart';

void main() {
  late Directory tempDir;
  late Directory originalDir;

  setUp(() {
    originalDir = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('bloom_js_create_test_');
  });

  tearDown(() {
    Directory.current = originalDir;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper that runs the `bloom js create` command inside [tempDir] and
  /// captures both the exit code and all printed lines.
  Future<(int, List<String>)> runCreate(List<String> args,
      {Directory? workDir}) async {
    final dir = workDir ?? tempDir;
    final previousDir = Directory.current;
    Directory.current = dir;

    final prints = <String>[];
    int? exitCode;
    try {
      await runZoned(() async {
        final runner = CommandRunner<int>('bloom', 'Bloom CLI')
          ..addCommand(JsCommand());
        exitCode = await runner.run(['js', ...args]);
      }, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          prints.add(line);
        },
      ));
    } finally {
      Directory.current = previousDir;
    }
    return (exitCode ?? 1, prints);
  }

  void createBloomProjectFixture(Directory dir) {
    File(p.join(dir.path, 'bloom.yaml'))
        .writeAsStringSync('name: test_app\n');
    File(p.join(dir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: test_app\n');
  }

  group('JsCreateCommand', () {
    test('registers create subcommand under JsCommand', () {
      final cmd = JsCommand();
      expect(cmd.subcommands.keys, contains('create'));
      expect(cmd.subcommands['create']!.name, 'create');
    });

    test('creates lib/components/widget.dart containing BloomNode Widget()',
        () async {
      createBloomProjectFixture(tempDir);

      final (exitCode, prints) = await runCreate(['create', 'Widget']);

      expect(exitCode, 0);

      final componentFile =
          File(p.join(tempDir.path, 'lib', 'components', 'widget.dart'));
      expect(componentFile.existsSync(), isTrue,
          reason: 'Component file should exist at ${componentFile.path}');
      final content = componentFile.readAsStringSync();
      expect(content, contains('BloomNode Widget()'));
      expect(content, contains("import 'package:bloom_js_native/bloom_js_native.dart'"));
      expect(content, contains("className: 'Widget'"));
    });

    test('also creates test/widget_test.dart', () async {
      createBloomProjectFixture(tempDir);

      final (exitCode, prints) = await runCreate(['create', 'Widget']);

      expect(exitCode, 0);

      final testFile = File(p.join(tempDir.path, 'test', 'widget_test.dart'));
      expect(testFile.existsSync(), isTrue,
          reason: 'Test file should exist at ${testFile.path}');
      final content = testFile.readAsStringSync();
      expect(content, contains('Widget renders'));
    });

    test('second run with same name returns non-zero and does not overwrite',
        () async {
      createBloomProjectFixture(tempDir);

      final (firstCode, _) = await runCreate(['create', 'Widget']);
      expect(firstCode, 0);

      final componentFile =
          File(p.join(tempDir.path, 'lib', 'components', 'widget.dart'));
      final originalContent = componentFile.readAsStringSync();

      final (secondCode, prints) = await runCreate(['create', 'Widget']);
      expect(secondCode, isNot(0));
      expect(prints.join('\n'), contains('already exists'));

      // File should not have been overwritten
      expect(componentFile.readAsStringSync(), equals(originalContent));
    });

    test('with no arguments returns non-zero with usage error', () async {
      createBloomProjectFixture(tempDir);

      final (exitCode, prints) = await runCreate(['create']);

      expect(exitCode, isNot(0));
      expect(prints.join('\n'), contains('Usage: bloom js create'));
    });

    test('with invalid name starting with digit returns validation error',
        () async {
      createBloomProjectFixture(tempDir);

      final (exitCode, prints) = await runCreate(['create', '123Invalid']);

      expect(exitCode, isNot(0));
      expect(prints.join('\n'), contains('Invalid component name'));
    });

    test('with --page flag creates lib/pages/dashboard.dart', () async {
      createBloomProjectFixture(tempDir);

      final (exitCode, prints) =
          await runCreate(['create', 'Dashboard', '--page']);

      expect(exitCode, 0);
      final pageFile =
          File(p.join(tempDir.path, 'lib', 'pages', 'dashboard.dart'));
      expect(pageFile.existsSync(), isTrue);
      final content = pageFile.readAsStringSync();
      expect(content, contains('BloomNode Dashboard(Map<String, String> params)'));
      expect(content, contains('BloomRoute'));
      expect(prints.join('\n'), contains('Created page:'));
    });

    test('outside Bloom project returns No Bloom project found error', () async {
      // tempDir intentionally has no bloom.yaml — do not create fixture
      final (exitCode, prints) = await runCreate(['create', 'Widget']);

      expect(exitCode, isNot(0));
      expect(prints.join('\n'), contains('No Bloom project found'));
    });
  });
}
