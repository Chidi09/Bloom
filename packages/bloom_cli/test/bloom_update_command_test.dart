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

    test('CLI update subcommands persist manifests, adjust rollouts with validation, and handle rollbacks', () async {
      final appDir = Directory(p.join(tempDir.path, 'cli_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: cli_app\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(UpdateCommand());

      // 1. Initial check (no updates yet)
      final checkEmptyCode = await runner.run(['update', 'check', '--project-dir=${appDir.path}']);
      expect(checkEmptyCode, 0);

      // 2. Publish update with 50% rollout
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

      // Verify manifest persistence in .bloom/updates/manifests.json
      final storageFile = File(p.join(appDir.path, '.bloom', 'updates', 'manifests.json'));
      expect(storageFile.existsSync(), isTrue);
      final content = storageFile.readAsStringSync();
      expect(content, contains('Hotfix 1.0.1'));
      expect(content, contains('"rollout_percentage": 50'));
      expect(content, contains('"status": "active"'));

      // Extract generated update ID
      final match = RegExp(r'"id":\s*"(upd_[^"]+)"').firstMatch(content);
      expect(match, isNotNull);
      final updateId = match!.group(1)!;

      // 3. Rollout range validation: reject invalid percentage > 100
      final invalidRolloutCode = await runner.run([
        'update',
        'rollout',
        '--id=$updateId',
        '--percentage=150',
        '--project-dir=${appDir.path}',
      ]);
      expect(invalidRolloutCode, 1);

      // 4. Valid rollout to 100%
      final validRolloutCode = await runner.run([
        'update',
        'rollout',
        '--id=$updateId',
        '--percentage=100',
        '--project-dir=${appDir.path}',
      ]);
      expect(validRolloutCode, 0);
      expect(storageFile.readAsStringSync(), contains('"rollout_percentage": 100'));

      // 5. Check reports available update
      final checkCode = await runner.run(['update', 'check', '--project-dir=${appDir.path}']);
      expect(checkCode, 0);

      // 6. Rollback
      final rollbackCode = await runner.run([
        'update',
        'rollback',
        '--channel=production',
        '--project-dir=${appDir.path}',
      ]);
      expect(rollbackCode, 0);
      expect(storageFile.readAsStringSync(), contains('"status": "rolled_back"'));

      // 7. Fingerprint command
      final fpCode = await runner.run(['update', 'fingerprint', '--project-dir=${appDir.path}']);
      expect(fpCode, 0);
    });
  });
}
