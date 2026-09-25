import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../lib/src/deployment/deployment_target_detector.dart';
import '../lib/src/templates/templates.dart';

void main() {
  test('both project templates link to the manifest schema URL', () async {
    final templateUri = await Isolate.resolvePackageUri(
      Uri.parse('package:bloom_cli/src/templates/templates.dart'),
    );
    expect(templateUri, isNotNull);
    final schemaFile = File.fromUri(
      templateUri!.resolve('../../../schema/bloom.schema.json'),
    );
    final schema =
        jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
    final schemaUrl = schema['\$id'] as String;
    expect(schema['required'], contains('name'));
    for (final yaml in [
      BloomTemplates.bloomYaml(name: 'flutter_app'),
      BloomTemplates.jsNativeBloomYaml(name: 'web_app'),
    ]) {
      expect(yaml.split('\n').first,
          '# yaml-language-server: \$schema=$schemaUrl');
    }
  });

  test('manifest schema describes supported target and mode values', () async {
    final templateUri = await Isolate.resolvePackageUri(
      Uri.parse('package:bloom_cli/src/templates/templates.dart'),
    );
    expect(templateUri, isNotNull);
    final schemaFile = File.fromUri(
      templateUri!.resolve('../../../schema/bloom.schema.json'),
    );
    final schema =
        jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    final topLevelTargets =
        (properties['target'] as Map<String, dynamic>)['enum'] as List;
    final deploymentProperties = (properties['deployment']
        as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
    final deploymentTargets = (deploymentProperties['target']
        as Map<String, dynamic>)['enum'] as List;
    final modes = (properties['mode'] as Map<String, dynamic>)['enum'] as List;

    expect(topLevelTargets, containsAll(['web_dom', 'web']));
    expect(
        deploymentTargets,
        containsAll([
          for (final target in BloomDeploymentTarget.values) target.id,
        ]));
    const aliases = [
      'js',
      'jsnative',
      'bloom_js_native',
      'js-native',
      'bloom-js-native',
      'backend',
      'bloom_server',
      'fullstack',
      'full_stack',
      'full-stack',
    ];
    expect(deploymentTargets, containsAll(aliases));
    expect(
      aliases.every((alias) => BloomDeploymentTarget.parse(alias) != null),
      isTrue,
    );
    expect(topLevelTargets, containsAll(deploymentTargets));
    expect(modes, containsAll(['managed', 'bare']));
    expect(modes, hasLength(2));

    final jsNativeManifest =
        loadYaml(BloomTemplates.jsNativeBloomYaml(name: 'web_app')) as YamlMap;
    expect(topLevelTargets, contains(jsNativeManifest['target']));
  });
}
