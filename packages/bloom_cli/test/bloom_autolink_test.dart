// test/bloom_autolink_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import '../lib/src/commands/autolink_command.dart';
import '../lib/src/commands/deps_command.dart';
import '../lib/src/commands/why_command.dart';
import '../lib/src/native/autolink_engine.dart';
import '../lib/src/utils/project.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_autolink_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 10: Autolinking, Dependency Graph & bloom.lock', () {
    test('Discovers modules, autolinks Android/iOS, applies to settings.gradle/Podfile, and writes deterministic bloom.lock', () async {
      // Setup host app structure
      final appDir = Directory(p.join(tempDir.path, 'my_app'))..createSync(recursive: true);
      final androidDir = Directory(p.join(appDir.path, 'android'))..createSync(recursive: true);
      final iosDir = Directory(p.join(appDir.path, 'ios'))..createSync(recursive: true);

      // Create settings.gradle and Podfile
      File(p.join(androidDir.path, 'settings.gradle')).writeAsStringSync('''
rootProject.name = 'my_app'
include ':app'
''');

      File(p.join(iosDir.path, 'Podfile')).writeAsStringSync('''
platform :ios, '15.0'
target 'Runner' do
  use_frameworks!
end
''');

      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: my_app
version: 1.0.0
mode: managed
plugins:
  - camera
''');

      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
version: 1.0.0
environment:
  sdk: '>=3.2.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  local_sensor:
    path: ../packages/local_sensor
''');

      // Setup local module in packages/local_sensor
      final moduleDir = Directory(p.join(tempDir.path, 'packages', 'local_sensor'))..createSync(recursive: true);
      final modAndroidDir = Directory(p.join(moduleDir.path, 'android'))..createSync(recursive: true);
      final modIosDir = Directory(p.join(moduleDir.path, 'ios'))..createSync(recursive: true);

      // Add a dummy native source file to test content fingerprinting
      File(p.join(modAndroidDir.path, 'SensorPlugin.kt')).writeAsStringSync('package dev.bloom\nclass SensorPlugin {}');
      File(p.join(modIosDir.path, 'SensorPlugin.swift')).writeAsStringSync('import Foundation\nclass SensorPlugin {}');

      File(p.join(moduleDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: local_sensor
version: 1.2.3
environment:
  sdk: '>=3.2.0 <4.0.0'
''');

      File(p.join(moduleDir.path, 'bloom.module.yaml')).writeAsStringSync('''
name: local_sensor
version: 1.2.3
platforms:
  android:
    min_sdk: 24
    target_sdk: 34
    dependencies:
      - "androidx.camera:camera-core:1.3.1"
  ios:
    min_version: "15.0"
    frameworks:
      - AVFoundation
permissions:
  camera:
    description: "Scan QR codes"
''');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(AutolinkCommand())
        ..addCommand(DepsCommand())
        ..addCommand(WhyCommand());

      // 1. Run bloom autolink with explicit project-dir
      final autolinkCode = await runner.run(['autolink', '--project-dir=${appDir.path}']);
      expect(autolinkCode, 0);

      // 2. Verify android/bloom_autolinking.gradle and injection into settings.gradle
      final gradleFile = File(p.join(appDir.path, 'android', 'bloom_autolinking.gradle'));
      expect(gradleFile.existsSync(), isTrue);
      final gradleContent = gradleFile.readAsStringSync();
      expect(gradleContent, contains("include ':local_sensor'"));

      final settingsFile = File(p.join(androidDir.path, 'settings.gradle'));
      expect(settingsFile.readAsStringSync(), contains('apply from: "bloom_autolinking.gradle"'));

      // 3. Verify ios/BloomAutolinking.podspec.json, BloomAutolinking.rb, and injection into Podfile
      final podspecJsonFile = File(p.join(appDir.path, 'ios', 'BloomAutolinking.podspec.json'));
      expect(podspecJsonFile.existsSync(), isTrue);
      final jsonContent = podspecJsonFile.readAsStringSync();
      expect(jsonContent, contains("local_sensor"));
      expect(jsonContent, contains("AVFoundation"));

      final rbFile = File(p.join(appDir.path, 'ios', 'BloomAutolinking.rb'));
      expect(rbFile.existsSync(), isTrue);
      expect(rbFile.readAsStringSync(), contains('def use_bloom_modules!'));

      final podfile = File(p.join(iosDir.path, 'Podfile'));
      expect(podfile.readAsStringSync(), contains("require_relative 'BloomAutolinking.rb'"));
      expect(podfile.readAsStringSync(), contains('use_bloom_modules!'));

      // 4. Verify deterministic bloom.lock (no generated_at timestamp!)
      final lockFile = File(p.join(appDir.path, 'bloom.lock'));
      expect(lockFile.existsSync(), isTrue);
      final lockContent = lockFile.readAsStringSync();
      expect(lockContent, isNot(contains('generated_at:')));
      expect(lockContent, contains("local_sensor:"));
      expect(lockContent, contains("version: 1.2.3"));
      expect(lockContent, contains("androidx.camera:camera-core:1.3.1"));
      expect(lockContent, contains("AVFoundation"));
      expect(lockContent, contains("fingerprint:"));

      // 5. Test bloom deps
      final depsCode = await runner.run(['deps', '--project-dir=${appDir.path}']);
      expect(depsCode, 0);

      // 6. Test bloom why local_sensor (handles Map permission format without throwing)
      final whyCode = await runner.run(['why', 'local_sensor', '--project-dir=${appDir.path}']);
      expect(whyCode, 0);
    });

    test('Positively detects duplicate native module version conflicts', () async {
      final conflictRoot = Directory(p.join(tempDir.path, 'conflict_workspace'))..createSync(recursive: true);
      final appDir = Directory(p.join(conflictRoot.path, 'apps', 'shop_app'))..createSync(recursive: true);

      // App depends on pkg_a and pkg_b
      File(p.join(appDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: shop_app
version: 1.0.0
dependencies:
  pkg_a:
    path: ../../packages/pkg_a
  pkg_b:
    path: ../../packages/pkg_b
''');
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: shop_app\n');

      // pkg_a depends on camera_module v1.0.0
      final pkgADir = Directory(p.join(conflictRoot.path, 'packages', 'pkg_a'))..createSync(recursive: true);
      File(p.join(pkgADir.path, 'pubspec.yaml')).writeAsStringSync('''
name: pkg_a
version: 1.0.0
dependencies:
  camera_module:
    path: ../camera_v1
''');

      // pkg_b depends on camera_module v2.0.0
      final pkgBDir = Directory(p.join(conflictRoot.path, 'packages', 'pkg_b'))..createSync(recursive: true);
      File(p.join(pkgBDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: pkg_b
version: 1.0.0
dependencies:
  camera_module:
    path: ../camera_v2
''');

      // camera_v1 native module
      final camV1Dir = Directory(p.join(conflictRoot.path, 'packages', 'camera_v1'))..createSync(recursive: true);
      File(p.join(camV1Dir.path, 'pubspec.yaml')).writeAsStringSync('name: camera_module\nversion: 1.0.0\n');
      File(p.join(camV1Dir.path, 'bloom.module.yaml')).writeAsStringSync('name: camera_module\nversion: 1.0.0\n');

      // camera_v2 native module
      final camV2Dir = Directory(p.join(conflictRoot.path, 'packages', 'camera_v2'))..createSync(recursive: true);
      File(p.join(camV2Dir.path, 'pubspec.yaml')).writeAsStringSync('name: camera_module\nversion: 2.0.0\n');
      File(p.join(camV2Dir.path, 'bloom.module.yaml')).writeAsStringSync('name: camera_module\nversion: 2.0.0\n');

      final bloomProj = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final engine = AutolinkEngine(bloomProj);
      final conflicts = engine.detectConflicts();

      // Positively verify conflict was caught!
      expect(conflicts.isNotEmpty, isTrue);
      expect(conflicts.first.moduleName, 'camera_module');
      expect(conflicts.first.conflictingVersions, containsAll(['1.0.0', '2.0.0']));

      // Verify runAutolink returns false on conflict
      final success = await engine.runAutolink();
      expect(success, isFalse);
    });
  });
}
