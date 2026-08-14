// test/bloom_deploy_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/deploy_command.dart';
import '../lib/src/deployment/shorebird_config.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('Phase 7: Shorebird Config & Synchronizer', () {
    test('parses ShorebirdConfig from map and outputs valid Shorebird schema without auto_update', () {
      final config = ShorebirdConfig.fromMap({
        'app_id': 'test-app-uuid-1234',
        'flavors': {
          'staging': 'staging-uuid-5678',
          'production': 'prod-uuid-9999',
        },
      });

      expect(config.appId, 'test-app-uuid-1234');
      expect(config.flavors['staging'], 'staging-uuid-5678');

      final yaml = config.toYamlContent(activeFlavor: 'staging');
      expect(yaml.contains('app_id: staging-uuid-5678'), true);
      expect(yaml.contains('auto_update'), false); // Validated: not in Shorebird schema
    });

    test('synchronizes shorebird.yaml into project root directory', () {
      final tempDir = Directory.systemTemp.createTempSync('bloom_shorebird_test_');

      try {
        final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
        bloomYaml.writeAsStringSync('''
name: my_ota_app
version: 1.0.0
deployment:
  shorebird:
    app_id: custom-app-id-xyz
''');

        final project = BloomProject.fromDirectory(tempDir);
        final synchronizer = ShorebirdSynchronizer(project);
        final file = synchronizer.sync();

        expect(file.existsSync(), true);
        final content = file.readAsStringSync();
        expect(content.contains('app_id: custom-app-id-xyz'), true);
        expect(content.contains('auto_update'), false);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('Phase 7: DeployCommand Validation & Execution', () {
    late Directory tempDir;
    late CommandRunner<int> runner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_deploy_cmd_test_');
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('''
name: deploy_sample
version: 1.0.0
flavors:
  staging:
    app_name: "Sample Staging"
''');

      final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes'))..createSync(recursive: true);
      File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class IndexRoute {}');

      // Create dummy android Manifest
      final androidDir = Directory(p.join(tempDir.path, 'android', 'app', 'src', 'main'))..createSync(recursive: true);
      File(p.join(androidDir.path, 'AndroidManifest.xml')).writeAsStringSync('<manifest package="dev.bloom.test"><application /></manifest>');

      runner = CommandRunner<int>('bloom', 'test')..addCommand(DeployCommand());
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('rejects invalid target platform with error exit code 1', () async {
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run(['deploy', '--target=windows']);
        expect(exitCode, 1);
      } finally {
        Directory.current = originalDir;
      }
    });

    test('rejects undefined flavor with error exit code 1', () async {
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run(['deploy', '--flavor=non_existent']);
        expect(exitCode, 1);
      } finally {
        Directory.current = originalDir;
      }
    });

    test('executes deploy dry run successfully on valid configuration', () async {
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run(['deploy', '--dry-run', '--channel=staging', '--target=android', '--flavor=staging']);
        expect(exitCode, 0);

        // Verify shorebird.yaml was generated
        final shorebirdFile = File(p.join(tempDir.path, 'shorebird.yaml'));
        expect(shorebirdFile.existsSync(), true);
      } finally {
        Directory.current = originalDir;
      }
    });

    test('returns exit code 1 when Shorebird CLI is not installed during real deploy attempt', () async {
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        // Without --dry-run, if shorebird is missing on system PATH, it must fail with exit code 1
        final exitCode = await runner.run(['deploy', '--channel=staging', '--target=android']);
        expect(exitCode, 1);
      } finally {
        Directory.current = originalDir;
      }
    });
  });
}
