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
    test('parses ShorebirdConfig from map and outputs valid YAML', () {
      final config = ShorebirdConfig.fromMap({
        'app_id': 'test-app-uuid-1234',
        'auto_update': true,
        'flavors': {
          'staging': 'staging-uuid-5678',
          'production': 'prod-uuid-9999',
        },
      });

      expect(config.appId, 'test-app-uuid-1234');
      expect(config.autoUpdate, true);
      expect(config.flavors['staging'], 'staging-uuid-5678');

      final yaml = config.toYamlContent(activeFlavor: 'staging');
      expect(yaml.contains('app_id: staging-uuid-5678'), true);
      expect(yaml.contains('auto_update: true'), true);
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
    auto_update: true
''');

        final project = BloomProject.fromDirectory(tempDir);
        final synchronizer = ShorebirdSynchronizer(project);
        final file = synchronizer.sync();

        expect(file.existsSync(), true);
        final content = file.readAsStringSync();
        expect(content.contains('app_id: custom-app-id-xyz'), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('Phase 7: DeployCommand Dry Run', () {
    test('executes deploy dry run successfully with route & prebuild sync', () async {
      final tempDir = Directory.systemTemp.createTempSync('bloom_deploy_cmd_test_');

      try {
        final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
        bloomYaml.writeAsStringSync('name: deploy_sample\nversion: 1.0.0\n');

        final routesDir = Directory(p.join(tempDir.path, 'lib', 'routes'))..createSync(recursive: true);
        File(p.join(routesDir.path, 'index.dart')).writeAsStringSync('class IndexRoute {}');

        // Create dummy android Manifest
        final androidDir = Directory(p.join(tempDir.path, 'android', 'app', 'src', 'main'))..createSync(recursive: true);
        File(p.join(androidDir.path, 'AndroidManifest.xml')).writeAsStringSync('<manifest package="dev.bloom.test"><application /></manifest>');

        final runner = CommandRunner<int>('bloom', 'test')..addCommand(DeployCommand());

        final originalDir = Directory.current;
        Directory.current = tempDir;

        try {
          final exitCode = await runner.run(['deploy', '--dry-run', '--channel=staging', '--target=android']);
          expect(exitCode, 0);

          // Verify shorebird.yaml was generated
          final shorebirdFile = File(p.join(tempDir.path, 'shorebird.yaml'));
          expect(shorebirdFile.existsSync(), true);
        } finally {
          Directory.current = originalDir;
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
