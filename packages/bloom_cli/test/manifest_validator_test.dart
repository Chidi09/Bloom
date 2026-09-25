import 'dart:io';

import 'package:test/test.dart';

import '../lib/src/templates/templates.dart';
import '../lib/src/utils/manifest_validator.dart';

void main() {
  late Directory tempDir;
  late File manifest;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_manifest_test_');
    manifest = File('${tempDir.path}${Platform.pathSeparator}bloom.yaml');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('accepts the generated JS Native manifest', () {
    manifest.writeAsStringSync(
      BloomTemplates.jsNativeBloomYaml(name: 'web_app'),
    );

    expect(BloomManifestValidator.validateFile(manifest), isEmpty);
  });

  test('reports malformed YAML and a non-mapping root', () {
    manifest.writeAsStringSync('name: [unterminated');
    expect(BloomManifestValidator.validateFile(manifest).single,
        startsWith('bloom.yaml could not be parsed:'));

    manifest.writeAsStringSync('- not-a-manifest-map');
    expect(BloomManifestValidator.validateFile(manifest), [
      'bloom.yaml must contain a mapping at its root',
    ]);
  });

  test('reports invalid CLI-owned fields together', () {
    manifest.writeAsStringSync('''
name: " "
schema: 0
mode: custom
target: not-a-target
deployment:
  target: not-a-deployment-target
''');

    expect(BloomManifestValidator.validateFile(manifest), [
      'name must be a non-empty string',
      'schema must be a positive integer',
      'mode must be either "managed" or "bare"',
      'target must be a supported Bloom target or "web_dom"/"web"',
      'deployment.target must be a supported Bloom deployment target',
    ]);
  });
}
