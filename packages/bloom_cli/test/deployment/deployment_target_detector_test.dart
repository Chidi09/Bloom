// test/deployment/deployment_target_detector_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/deployment/deployment_target_detector.dart';
import 'package:bloom_cli/src/utils/project.dart';

void main() {
  late Directory tempDir;
  const detector = BloomDeploymentTargetDetector();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_target_detect_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BloomDeploymentTargetDetector', () {
    test('detects Flutter target for standard Flutter application', () {
      final appDir = Directory(p.join(tempDir.path, 'flutter_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: flutter_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: flutter_demo
environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'
dependencies:
  flutter:
    sdk: flutter
''');
      Directory(p.join(appDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(appDir.path, 'lib', 'main.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';
void main() => runApp(const MaterialApp());
''');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.flutter);
      expect(result.appName, 'flutter_demo');
      expect(result.hasFlutter, isTrue);
      expect(result.hasServer, isFalse);
      expect(result.hasJsNative, isFalse);
      expect(result.services, contains('web'));
      expect(result.reasons, isNotEmpty);
    });

    test('detects JS Native target for pure Dart web application', () {
      final appDir = Directory(p.join(tempDir.path, 'js_native_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: js_native_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: js_native_demo
dependencies:
  bloom_js_native: ^0.1.0
''');
      Directory(p.join(appDir.path, 'web'))..createSync(recursive: true);
      File(p.join(appDir.path, 'web', 'main.dart'))
          .writeAsStringSync('void main() {}');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.jsNative);
      expect(result.appName, 'js_native_demo');
      expect(result.hasJsNative, isTrue);
      expect(result.hasFlutter, isFalse);
      expect(result.hasServer, isFalse);
      expect(result.services, ['web']);
    });

    test('detects Bloom Server target for backend project with bin/server.dart',
        () {
      final appDir = Directory(p.join(tempDir.path, 'server_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: api_server\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: api_server
dependencies:
  bloom_framework: ^0.2.2
  bloom_db: ^0.1.0
''');
      Directory(p.join(appDir.path, 'bin'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bin', 'server.dart'))
          .writeAsStringSync('void main() {}');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.server);
      expect(result.appName, 'api_server');
      expect(result.hasServer, isTrue);
      expect(result.hasFlutter, isFalse);
      expect(result.hasJsNative, isFalse);
      expect(result.services, contains('server'));
    });

    test('requires actual runnable server entrypoint before detecting server target',
        () {
      final appDir = Directory(p.join(tempDir.path, 'no_entry_server_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: lib_only_app\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: lib_only_app
dependencies:
  bloom_framework: ^0.2.2
  bloom_db: ^0.1.0
''');
      // No bin/server.dart exists

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      // Must not classify as server without a runnable server entrypoint
      expect(result.target, isNot(BloomDeploymentTarget.server));
      expect(result.hasServer, isFalse);
    });

    test(
        'detects Hybrid target when both client and server are present in single project',
        () {
      final appDir = Directory(p.join(tempDir.path, 'hybrid_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: fullstack_app\n');
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: fullstack_app
dependencies:
  flutter:
    sdk: flutter
  bloom_framework: ^0.2.2
''');
      Directory(p.join(appDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(appDir.path, 'lib', 'main.dart')).writeAsStringSync(
          'import "package:flutter/material.dart"; void main() => runApp(Container());');
      Directory(p.join(appDir.path, 'bin'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bin', 'server.dart'))
          .writeAsStringSync('void main() {}');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.hybrid);
      expect(result.appName, 'fullstack_app');
      expect(result.hasServer, isTrue);
      expect(result.hasFlutter, isTrue);
      expect(result.services, containsAll(['web', 'server', 'db']));
    });

    test('detects Hybrid target for multi-app workspace under apps/', () {
      final appDir = Directory(p.join(tempDir.path, 'monorepo_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: monorepo_demo\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: monorepo_demo\n');

      Directory(p.join(appDir.path, 'apps', 'web'))
        ..createSync(recursive: true);
      Directory(p.join(appDir.path, 'apps', 'server'))
        ..createSync(recursive: true);

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.hybrid);
      expect(result.services, containsAll(['web', 'server', 'db']));
    });

    test('respects explicit CLI override over auto-detection', () {
      final appDir = Directory(p.join(tempDir.path, 'override_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml'))
          .writeAsStringSync('name: my_app\n');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: my_app\n');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project, explicitTarget: 'server');

      expect(result.target, BloomDeploymentTarget.server);
      expect(result.reasons.first, contains('Explicit target override'));
    });

    test('respects target configured in bloom.yaml', () {
      final appDir = Directory(p.join(tempDir.path, 'yaml_target_app'))
        ..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: configured_app
deployment:
  target: js_native
''');
      File(p.join(appDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: configured_app\n');

      final project = BloomProject.fromDirectory(appDir);
      final result = detector.detect(project);

      expect(result.target, BloomDeploymentTarget.jsNative);
    });
  });
}
