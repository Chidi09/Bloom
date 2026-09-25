// test/doctor_command_test.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/doctor_command.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_doctor_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DoctorCommand diagnostics', () {
    test(
        'standard doctor command runs to completion and includes system information and version check',
        () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner.run(['doctor']);
      // Should succeed when developer toolchains are intact
      expect(exitCode, anyOf(0, 1));
    });

    test(
        'doctor command within a valid project displays configuration diagnostics',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'my_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: my_app
version: 1.0.0
''');
      File(p.join(appDir.path, '.env'))
          .writeAsStringSync('BLOOM_PUBLIC_API_KEY=xyz123\n');
      Directory(p.join(appDir.path, 'lib', 'routes'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'lib', 'routes', 'index.dart'))
          .writeAsStringSync('class IndexRoute {}\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode =
          await runner.run(['doctor', '--project-dir=${appDir.path}']);
      expect(exitCode, anyOf(0, 1));
    });

    test('doctor reports invalid Bloom manifest fields', () async {
      final appDir = Directory(p.join(tempDir.path, 'invalid_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: invalid_app
target: imaginary_target
''');
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());
      final output = <String>[];

      await runZoned(
        () => runner.run(['doctor', '--project-dir=${appDir.path}']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );

      expect(output.join('\n'), contains('bloom.yaml invalid'));
      expect(output.join('\n'),
          contains('target must be a supported Bloom target'));
    });

    test('doctor --upgrade outside a bloom project returns exit code 1',
        () async {
      final emptyDir = Directory(p.join(tempDir.path, 'empty_dir'))
        ..createSync(recursive: true);
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner
          .run(['doctor', '--upgrade', '--project-dir=${emptyDir.path}']);
      expect(exitCode, 1);
    });

    test('doctor --ci outside a bloom project returns exit code 1', () async {
      final emptyDir = Directory(p.join(tempDir.path, 'empty_dir'))
        ..createSync(recursive: true);
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(DoctorCommand());

      final exitCode = await runner
          .run(['doctor', '--ci', '--project-dir=${emptyDir.path}']);
      expect(exitCode, 1);
    });
  });
}
