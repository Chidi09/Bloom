// test/bloom_create_module_test.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/create_module_command.dart';
import '../lib/src/commands/generate_command.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_module_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 9: Bloom Module Authoring & Code Generator', () {
    test('Scaffolds module, compiles @BloomModule DSL, and generates typed bridges', () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(CreateCommand())
        ..addCommand(GenerateCommand());

      final prevDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run([
          'create',
          'module',
          'bluetooth_beacon',
          '--org',
          'io.bloom.iot',
          '--description',
          'Bluetooth beacon scanner native module',
        ]);

        expect(exitCode, 0);

        final moduleDir = Directory(p.join(tempDir.path, 'bluetooth_beacon'));
        expect(moduleDir.existsSync(), isTrue);

        // 1. Manifest
        final manifestFile = File(p.join(moduleDir.path, 'bloom.module.yaml'));
        expect(manifestFile.existsSync(), isTrue);
        final manifestContent = manifestFile.readAsStringSync();
        expect(manifestContent, contains('name: bluetooth_beacon'));
        expect(manifestContent, contains('Bluetooth beacon scanner native module'));
        expect(manifestContent, contains('BluetoothBeaconConfigPlugin'));

        // 2. Pubspec
        final pubspecFile = File(p.join(moduleDir.path, 'pubspec.yaml'));
        expect(pubspecFile.existsSync(), isTrue);
        expect(pubspecFile.readAsStringSync(), contains('bloom_framework'));

        // 3. Dart Module DSL
        final dslFile = File(p.join(moduleDir.path, 'lib', 'src', 'bluetooth_beacon.module.dart'));
        expect(dslFile.existsSync(), isTrue);
        final dslContent = dslFile.readAsStringSync();
        expect(dslContent, contains('@BloomModule('));
        expect(dslContent, contains('abstract class BluetoothBeaconDefinition'));

        // 4. Auto-Generated Typed Dart Bridge (.g.dart)
        final gDartFile = File(p.join(moduleDir.path, 'lib', 'src', 'bluetooth_beacon.g.dart'));
        expect(gDartFile.existsSync(), isTrue);
        final gDartContent = gDartFile.readAsStringSync();
        expect(gDartContent, contains('abstract class BloomBluetoothBeaconBridge extends BloomNativeModule implements BluetoothBeaconDefinition'));
        expect(gDartContent, contains('Future<Map<String, dynamic>> executeAction'));

        // 5. Dart Public API extends generated bridge
        final apiFile = File(p.join(moduleDir.path, 'lib', 'bluetooth_beacon.dart'));
        expect(apiFile.existsSync(), isTrue);
        expect(apiFile.readAsStringSync(), contains('class BluetoothBeacon extends BloomBluetoothBeaconBridge'));

        // 6. Native Android Kotlin & Kotlin Bridge
        final kotlinFile = File(p.join(
          moduleDir.path,
          'android/src/main/kotlin/io/bloom/iot/bluetooth_beacon/BluetoothBeaconModule.kt',
        ));
        expect(kotlinFile.existsSync(), isTrue);
        expect(kotlinFile.readAsStringSync(), contains('class BluetoothBeaconModule : BloomNativeModule()'));

        final kotlinBridgeFile = File(p.join(
          moduleDir.path,
          'android/src/main/kotlin/io/bloom/iot/bluetooth_beacon/BluetoothBeaconBridge.kt',
        ));
        expect(kotlinBridgeFile.existsSync(), isTrue);
        expect(kotlinBridgeFile.readAsStringSync(), contains('interface BluetoothBeaconModuleBridge'));

        // 7. Native iOS Swift & Swift Bridge
        final swiftFile = File(p.join(
          moduleDir.path,
          'ios/Sources/BluetoothBeaconModule.swift',
        ));
        expect(swiftFile.existsSync(), isTrue);
        expect(swiftFile.readAsStringSync(), contains('public class BluetoothBeaconModule: BloomNativeModule'));

        final swiftBridgeFile = File(p.join(
          moduleDir.path,
          'ios/Sources/BluetoothBeaconBridge.swift',
        ));
        expect(swiftBridgeFile.existsSync(), isTrue);
        expect(swiftBridgeFile.readAsStringSync(), contains('public protocol BluetoothBeaconModuleBridge: AnyObject'));

        // 8. Test regenerating via bloom generate module
        gDartFile.deleteSync();
        expect(gDartFile.existsSync(), isFalse);

        final genCode = await runner.run([
          'generate',
          'module',
          moduleDir.path,
        ]);
        expect(genCode, 0);
        expect(gDartFile.existsSync(), isTrue);
      } finally {
        Directory.current = prevDir;
      }
    });

    test('Scaffolds module via create-module command', () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(CreateModuleCommand());

      final prevDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run([
          'create-module',
          'biometric_auth',
        ]);

        expect(exitCode, 0);

        final moduleDir = Directory(p.join(tempDir.path, 'biometric_auth'));
        expect(moduleDir.existsSync(), isTrue);
        expect(File(p.join(moduleDir.path, 'bloom.module.yaml')).existsSync(), isTrue);
        expect(File(p.join(moduleDir.path, 'lib', 'src', 'biometric_auth.g.dart')).existsSync(), isTrue);
      } finally {
        Directory.current = prevDir;
      }
    });

    test('Rejects invalid module name with error exit code 1', () async {
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(CreateModuleCommand());

      final prevDir = Directory.current;
      Directory.current = tempDir;

      try {
        final exitCode = await runner.run([
          'create-module',
          '123_invalid_module!',
        ]);

        expect(exitCode, 1);
      } finally {
        Directory.current = prevDir;
      }
    });
  });
}
