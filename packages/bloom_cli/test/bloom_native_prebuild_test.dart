// test/bloom_native_prebuild_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/native/android_prebuild.dart';
import '../lib/src/native/ios_prebuild.dart';
import '../lib/src/native/prebuild_engine.dart';
import '../lib/src/utils/project.dart';

void main() {
  group('Phase 3: Native Prebuild Engine', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_prebuild_test_');

      // Create Android structure
      final androidMain = Directory(p.join(tempDir.path, 'android', 'app', 'src', 'main'))..createSync(recursive: true);
      File(p.join(androidMain.path, 'AndroidManifest.xml')).writeAsStringSync('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="TestApp">
    </application>
</manifest>''');

      // Create iOS structure
      final iosRunner = Directory(p.join(tempDir.path, 'ios', 'Runner'))..createSync(recursive: true);
      File(p.join(iosRunner.path, 'Info.plist')).writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>TestApp</string>
</dict>
</plist>''');

      // Create bloom.yaml and pubspec.yaml
      File(p.join(tempDir.path, 'bloom.yaml')).writeAsStringSync('''schema: 1
name: test_prebuild_app
plugins:
  - camera
  - notifications
''');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: test_prebuild_app\n');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('AndroidPrebuild injects permissions into AndroidManifest.xml', () async {
      final androidDir = Directory(p.join(tempDir.path, 'android'));
      final prebuild = AndroidPrebuild(androidDir);

      await prebuild.synchronize(
        platforms: {'android': {'min_sdk': 24}},
        plugins: ['camera', 'notifications'],
      );

      final manifest = File(p.join(androidDir.path, 'app', 'src', 'main', 'AndroidManifest.xml')).readAsStringSync();
      expect(manifest.contains('android.permission.INTERNET'), true);
      expect(manifest.contains('android.permission.CAMERA'), true);
      expect(manifest.contains('android.permission.POST_NOTIFICATIONS'), true);
    });

    test('IosPrebuild injects usage descriptions into Info.plist', () async {
      final iosDir = Directory(p.join(tempDir.path, 'ios'));
      final prebuild = IosPrebuild(iosDir);

      await prebuild.synchronize(
        platforms: {'ios': {'minimum_version': '15.0'}},
        plugins: ['camera'],
      );

      final plist = File(p.join(iosDir.path, 'Runner', 'Info.plist')).readAsStringSync();
      expect(plist.contains('<key>NSCameraUsageDescription</key>'), true);
      expect(plist.contains('<key>NSMicrophoneUsageDescription</key>'), true);
    });

    test('PrebuildEngine runs full multi-platform synchronization', () async {
      final project = BloomProject(
        rootDir: tempDir,
        bloomYamlFile: File(p.join(tempDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(tempDir.path, 'pubspec.yaml')),
      );

      final engine = PrebuildEngine(project);
      final success = await engine.run();
      expect(success, true);
    });
  });
}
