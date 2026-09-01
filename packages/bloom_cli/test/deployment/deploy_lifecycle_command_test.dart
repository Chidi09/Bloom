// test/deployment/deploy_lifecycle_command_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/commands/deploy_command.dart';

void main() {
  late Directory tempDir;
  late CommandRunner<int> runner;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('bloom_deploy_lifecycle_test_');
    runner = CommandRunner<int>('bloom', 'Bloom CLI')
      ..addCommand(DeployCommand());
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('bloom deploy init', () {
    test(
        'initializes Flutter deployment configuration and generates .env.example',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'flutter_init_app'))
        ..createSync(recursive: true);
      final bloomYaml = File(p.join(appDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: init_flutter_app\n');

      final pubspec = File(p.join(appDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('''
name: init_flutter_app
dependencies:
  flutter:
    sdk: flutter
''');

      final exitCode = await runner.run([
        'deploy',
        'init',
        '--project-dir=${appDir.path}',
        '--non-interactive'
      ]);
      expect(exitCode, 0);

      expect(bloomYaml.readAsStringSync(), contains('deployment:'));
      expect(bloomYaml.readAsStringSync(), contains('target: flutter'));

      final envExample = File(p.join(appDir.path, '.env.example'));
      expect(envExample.existsSync(), isTrue);
      expect(
          envExample.readAsStringSync(), contains('APP_NAME=init_flutter_app'));
    });

    test('initializes Server deployment configuration with target override',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'server_init_app'))
        ..createSync(recursive: true);
      final bloomYaml = File(p.join(appDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: init_server_app\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: init_server_app\n');

      final exitCode = await runner.run([
        'deploy',
        'init',
        '--target=server',
        '--project-dir=${appDir.path}'
      ]);
      expect(exitCode, 0);

      expect(bloomYaml.readAsStringSync(), contains('target: server'));
    });

    test('--dry-run validates init plan without writing files to disk',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'dry_run_init_app'))
        ..createSync(recursive: true);
      final bloomYaml = File(p.join(appDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: dry_init_app\n');

      final pubspec = File(p.join(appDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('''
name: dry_init_app
dependencies:
  flutter:
    sdk: flutter
''');

      final exitCode = await runner.run([
        'deploy',
        'init',
        '--dry-run',
        '--project-dir=${appDir.path}',
        '--non-interactive'
      ]);
      expect(exitCode, 0);

      expect(bloomYaml.readAsStringSync(), isNot(contains('deployment:')));
      final envExample = File(p.join(appDir.path, '.env.example'));
      expect(envExample.existsSync(), isFalse);
    });

    test('returns exit code 1 when executed outside a valid Bloom project',
        () async {
      final emptyDir = Directory(p.join(tempDir.path, 'empty_dir'))
        ..createSync(recursive: true);
      final exitCode = await runner
          .run(['deploy', 'init', '--project-dir=${emptyDir.path}']);
      expect(exitCode, 1);
    });
  });

  group('bloom deploy docker', () {
    test('generates full container bundle into project root', () async {
      final appDir = Directory(p.join(tempDir.path, 'docker_gen_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: gen_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: gen_demo
dependencies:
  flutter:
    sdk: flutter
''');

      final exitCode = await runner
          .run(['deploy', 'docker', '--project-dir=${appDir.path}']);
      expect(exitCode, 0);

      expect(File(p.join(appDir.path, 'Dockerfile')).existsSync(), isTrue);
      expect(File(p.join(appDir.path, '.dockerignore')).existsSync(), isTrue);
      expect(
          File(p.join(appDir.path, 'docker-compose.yml')).existsSync(), isTrue);
      expect(File(p.join(appDir.path, '.env.example')).existsSync(), isTrue);
    });

    test('--dry-run validates plan and generates 0 files on disk', () async {
      final appDir = Directory(p.join(tempDir.path, 'dry_run_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: dry_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: dry_demo\n');

      final exitCode = await runner.run(
          ['deploy', 'docker', '--dry-run', '--project-dir=${appDir.path}']);
      expect(exitCode, 0);

      expect(File(p.join(appDir.path, 'Dockerfile')).existsSync(), isFalse);
      expect(File(p.join(appDir.path, 'docker-compose.yml')).existsSync(),
          isFalse);
    });

    test(
        '--production-only generates Dockerfile and .dockerignore but omits docker-compose.yml',
        () async {
      final appDir = Directory(p.join(tempDir.path, 'prod_only_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: prod_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: prod_demo\n');

      final exitCode = await runner.run([
        'deploy',
        'docker',
        '--production-only',
        '--project-dir=${appDir.path}'
      ]);
      expect(exitCode, 0);

      expect(File(p.join(appDir.path, 'Dockerfile')).existsSync(), isTrue);
      expect(File(p.join(appDir.path, '.dockerignore')).existsSync(), isTrue);
      expect(File(p.join(appDir.path, 'docker-compose.yml')).existsSync(),
          isFalse);
    });

    test('--output writes bundle into dedicated output directory', () async {
      final appDir = Directory(p.join(tempDir.path, 'output_app'))
        ..createSync(recursive: true);
      final customOut = Directory(p.join(tempDir.path, 'custom_docker_out'))
        ..createSync(recursive: true);

      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: out_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: out_demo\n');

      final exitCode = await runner.run([
        'deploy',
        'docker',
        '--output=${customOut.path}',
        '--project-dir=${appDir.path}'
      ]);
      expect(exitCode, 0);

      expect(File(p.join(customOut.path, 'Dockerfile')).existsSync(), isTrue);
      expect(
          File(p.join(customOut.path, '.dockerignore')).existsSync(), isTrue);
      expect(File(p.join(appDir.path, 'Dockerfile')).existsSync(), isFalse);
    });
  });
}
