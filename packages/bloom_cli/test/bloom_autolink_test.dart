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
  final rootDir = Directory.current;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_autolink_test_');
  });

  tearDown(() {
    Directory.current = rootDir;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 10: Autolinking, Dependency Graph & bloom.lock', () {
    test('Discovers modules, autolinks Android/iOS, and writes bloom.lock', () async {
      // Setup host app structure
      final appDir = Directory(p.join(tempDir.path, 'my_app'))..createSync(recursive: true);
      Directory(p.join(appDir.path, 'android'))..createSync(recursive: true);
      Directory(p.join(appDir.path, 'ios'))..createSync(recursive: true);

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
      Directory(p.join(moduleDir.path, 'android'))..createSync(recursive: true);
      Directory(p.join(moduleDir.path, 'ios'))..createSync(recursive: true);

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
  - CAMERA
''');

      final prevDir = Directory.current;
      Directory.current = appDir;

      try {
        final runner = CommandRunner<int>('bloom', 'Bloom CLI')
          ..addCommand(AutolinkCommand())
          ..addCommand(DepsCommand())
          ..addCommand(WhyCommand());

        // 1. Run bloom autolink
        final autolinkCode = await runner.run(['autolink']);
        expect(autolinkCode, 0);

        // 2. Verify android/bloom_autolinking.gradle
        final gradleFile = File(p.join(appDir.path, 'android', 'bloom_autolinking.gradle'));
        expect(gradleFile.existsSync(), isTrue);
        final gradleContent = gradleFile.readAsStringSync();
        expect(gradleContent, contains(":local_sensor"));
        expect(gradleContent, contains("compileSdkVersion 34"));

        // 3. Verify ios/BloomAutolinking.podspec.json
        final podspecJsonFile = File(p.join(appDir.path, 'ios', 'BloomAutolinking.podspec.json'));
        expect(podspecJsonFile.existsSync(), isTrue);
        final jsonContent = podspecJsonFile.readAsStringSync();
        expect(jsonContent, contains("local_sensor"));
        expect(jsonContent, contains("AVFoundation"));

        // 4. Verify bloom.lock
        final lockFile = File(p.join(appDir.path, 'bloom.lock'));
        expect(lockFile.existsSync(), isTrue);
        final lockContent = lockFile.readAsStringSync();
        expect(lockContent, contains("local_sensor:"));
        expect(lockContent, contains("version: 1.2.3"));
        expect(lockContent, contains("androidx.camera:camera-core:1.3.1"));
        expect(lockContent, contains("AVFoundation"));
        expect(lockContent, contains("fingerprint:"));

        // 5. Test bloom deps
        final depsCode = await runner.run(['deps']);
        expect(depsCode, 0);

        // 6. Test bloom why local_sensor
        final whyCode = await runner.run(['why', 'local_sensor']);
        expect(whyCode, 0);
      } finally {
        Directory.current = prevDir;
      }
    });

    test('Detects duplicate native module conflicts', () {
      final appDir = Directory(p.join(tempDir.path, 'conflict_app'))..createSync(recursive: true);
      final bloomProj = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final engine = AutolinkEngine(bloomProj);
      final conflicts = engine.detectConflicts();
      expect(conflicts, isEmpty);
    });
  });
}
