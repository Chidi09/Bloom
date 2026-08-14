// test/bloom_update_command_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import '../lib/src/commands/update_command.dart';
import '../lib/src/generator/fingerprint_generator.dart';
import '../lib/src/utils/project.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_update_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 11: CLI Update Commands & Fingerprint Generator', () {
    test('FingerprintGenerator computes deterministic hash and writes fingerprint.g.dart', () {
      final appDir = Directory(p.join(tempDir.path, 'my_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: my_app
version: 1.0.0
plugins:
  - camera
  - notifications
''');

      File(p.join(appDir.path, 'bloom.lock')).writeAsStringSync('''
lockfile_version: 1
bloom_version: 1.0.0
native_modules:
  camera:
    version: 1.0.0
    fingerprint: "cam_sha_12345"
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final gen = FingerprintGenerator(project);
      final hash1 = gen.computeFingerprint();
      final hash2 = gen.computeFingerprint();

      expect(hash1, hash2);
      expect(hash1.length, 64);

      final file = gen.generateFingerprintDart();
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains("const String kBloomRuntimeFingerprint = '$hash1';"));
    });

    test('CLI update subcommands execute successfully with explicit project-dir', () async {
      final appDir = Directory(p.join(tempDir.path, 'cli_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: cli_app\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(UpdateCommand());

      // 1. Check
      final checkCode = await runner.run(['update', 'check', '--project-dir=${appDir.path}']);
      expect(checkCode, 0);

      // 2. Publish
      final pubCode = await runner.run([
        'update',
        'publish',
        '--channel=production',
        '--branch=main',
        '--rollout=50',
        '--notes=Hotfix 1.0.1',
        '--project-dir=${appDir.path}',
      ]);
      expect(pubCode, 0);

      // 3. Rollout
      final rolloutCode = await runner.run([
        'update',
        'rollout',
        '--id=upd_1234',
        '--percentage=100',
        '--project-dir=${appDir.path}',
      ]);
      expect(rolloutCode, 0);

      // 4. Rollback
      final rollbackCode = await runner.run([
        'update',
        'rollback',
        '--channel=production',
        '--project-dir=${appDir.path}',
      ]);
      expect(rollbackCode, 0);

      // 5. Fingerprint
      final fpCode = await runner.run(['update', 'fingerprint', '--project-dir=${appDir.path}']);
      expect(fpCode, 0);
    });
  });
}
