import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves a temporary DDC fixture against this checkout's JS Native package.
Future<File> createJsNativePackageConfig(Directory fixtureRoot) async {
  final packageDir = Directory(p.normalize(p.join(
    Directory.current.path,
    '..',
    'bloom_js_native',
  )));
  if (!File(p.join(packageDir.path, 'pubspec.yaml')).existsSync()) {
    throw StateError('Run this test from packages/bloom_cli.');
  }

  File(p.join(fixtureRoot.path, 'pubspec.yaml')).writeAsStringSync('''
name: bloom_ddc_fixture
publish_to: none
environment:
  sdk: '>=3.4.0 <4.0.0'
dependencies:
  bloom_js_native:
    path: ${jsonEncode(packageDir.path)}
''');

  final result = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: fixtureRoot.path,
  );
  if (result.exitCode != 0) {
    throw StateError('Fixture dart pub get failed: ${result.stderr}');
  }
  return File(p.join(fixtureRoot.path, '.dart_tool', 'package_config.json'));
}
