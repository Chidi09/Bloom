// test/bloom_build_env_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/commands/build_command.dart';

void main() {
  group('BuildCommand Client Environment Security', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_build_env_test_');

      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: test_app
version: 1.0.0
flavors:
  production:
    env_file: .env.production
  staging:
    env_file: .env.staging
''');

      final pubspecYaml = File(p.join(tempDir.path, 'pubspec.yaml'));
      pubspecYaml.writeAsStringSync('name: test_app\n');

      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(libDir.path, 'main.dart')).writeAsStringSync('void main() {}');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('fails web build when non-public environment variable is present in env file', () async {
      final envFile = File(p.join(tempDir.path, '.env.production'));
      envFile.writeAsStringSync('''
BLOOM_PUBLIC_API_URL=https://api.example.com
DATABASE_PASSWORD=super_secret_db_password
''');

      bool processCalled = false;
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (exec, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            processCalled = true;
            return ProcessResult(1234, 0, '', '');
          },
        ));

      final exitCode = await runner.run([
        'build',
        'web_dom',
        '--project-dir',
        tempDir.path,
        '--env-file',
        '.env.production',
      ]);

      expect(exitCode, 1);
      expect(processCalled, isFalse); // Build was halted before running compiler
    });

    test('fails web build when variable contains BLOOM_PUBLIC_ but does not start with it', () async {
      final envFile = File(p.join(tempDir.path, '.env.staging'));
      envFile.writeAsStringSync('''
MY_BLOOM_PUBLIC_API_KEY=not_really_public_prefix
''');

      bool processCalled = false;
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (exec, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            processCalled = true;
            return ProcessResult(1234, 0, '', '');
          },
        ));

      final exitCode = await runner.run([
        'build',
        'web_dom',
        '--project-dir',
        tempDir.path,
        '--env-file',
        '.env.staging',
      ]);

      expect(exitCode, 1);
      expect(processCalled, isFalse);
    });

    test('succeeds web build when all environment variables have BLOOM_PUBLIC_ prefix', () async {
      final envFile = File(p.join(tempDir.path, '.env.production'));
      envFile.writeAsStringSync('''
# Comments and blank lines are ignored
BLOOM_PUBLIC_API_URL=https://api.example.com
BLOOM_PUBLIC_THEME=dark
BLOOM_PUBLIC_APP_NAME="Bloom App"
''');

      bool processCalled = false;
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(BuildCommand(
          processRunner: (exec, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false, mode = ProcessStartMode.normal}) async {
            processCalled = true;
            return ProcessResult(1234, 0, '', '');
          },
        ));

      final exitCode = await runner.run([
        'build',
        'web_dom',
        '--project-dir',
        tempDir.path,
        '--env-file',
        '.env.production',
      ]);

      expect(exitCode, 0);
      expect(processCalled, isTrue); // Compiler was invoked
    });
  });
}
