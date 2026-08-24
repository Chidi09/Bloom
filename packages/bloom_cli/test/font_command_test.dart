// test/font_command_test.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/font_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FontCommand CLI', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_font_cmd_test_');
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_font_cmd_app\nversion: 1.0.0\n');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('returns 1 when --project-dir is invalid', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run(['fonts', 'optimize', '--family', 'Inter', '--project-dir', '/non/existent/path/xyz']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Not a valid Bloom project directory'));
    });

    test('returns 1 when no --family is specified', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run(['fonts', 'optimize', '--project-dir', tempDir.path]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('At least one --family must be specified'));
    });

    test('executes optimize subcommand and prints summary', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'fonts',
          'optimize',
          '--family',
          'Inter',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Font Optimization Summary:'));
      expect(fullOutput, contains('Families processed: 1'));
      // Exit code will be 0 on success or 1 only if all families fail
      expect(exitCode, anyOf(equals(0), equals(1)));
    });
  });
}
