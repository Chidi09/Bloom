// test/bloom_modules_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;
import 'package:bloom_framework/bloom.dart';

class MockPlatformCameraModule extends BloomNativeModule {
  bool resumedCalled = false;
  bool pausedCalled = false;

  MockPlatformCameraModule()
      : super(
          name: 'BloomCamera',
          version: '1.2.0',
        );

  @override
  void onHostResume() {
    resumedCalled = true;
  }

  @override
  void onHostPause() {
    pausedCalled = true;
  }
}

void main() {
  setUp(() {
    Bloom.reset();
  });

  group('Phase 9: Bloom Module DSL & Annotations', () {
    test('Annotation properties retain metadata values', () {
      const moduleMeta = BloomModule(
        name: 'BloomLocation',
        version: '2.0.0',
        description: 'GPS and geofencing native module',
      );

      expect(moduleMeta.name, 'BloomLocation');
      expect(moduleMeta.version, '2.0.0');
      expect(moduleMeta.description, 'GPS and geofencing native module');

      const asyncFunc = BloomAsyncFunction(thread: NativeThread.background, name: 'getCurrentPosition');
      expect(asyncFunc.thread, NativeThread.background);
      expect(asyncFunc.name, 'getCurrentPosition');

      const view = BloomView(name: 'MapView');
      expect(view.name, 'MapView');
    });
  });

  group('Phase 9: BloomModuleManifest Parsing (bloom.module.yaml)', () {
    const validManifestYaml = '''
name: bloom_camera
version: 1.2.0
description: "Native Camera module for Bloom"

platforms:
  android:
    min_sdk: 24
    target_sdk: 34
    dependencies:
      - "androidx.camera:camera-camera2:1.3.1"
      - "androidx.camera:camera-lifecycle:1.3.1"
  ios:
    min_version: "15.0"
    frameworks:
      - AVFoundation
      - CoreMedia

permissions:
  camera:
    android: "android.permission.CAMERA"
    ios: "NSCameraUsageDescription"
    default_prompt: "Allow camera access to capture photos."
    optional: false
  microphone:
    android: "android.permission.RECORD_AUDIO"
    ios: "NSMicrophoneUsageDescription"
    optional: true

config_plugin:
  class_name: BloomCameraConfigPlugin
''';

    test('Parses complete module manifest from YAML', () {
      final manifest = BloomModuleManifest.fromYaml(validManifestYaml);

      expect(manifest.name, 'bloom_camera');
      expect(manifest.version, '1.2.0');
      expect(manifest.description, 'Native Camera module for Bloom');

      // Android spec
      expect(manifest.android.minSdk, 24);
      expect(manifest.android.targetSdk, 34);
      expect(manifest.android.dependencies.length, 2);
      expect(manifest.android.dependencies.first, 'androidx.camera:camera-camera2:1.3.1');

      // iOS spec
      expect(manifest.ios.minVersion, '15.0');
      expect(manifest.ios.frameworks, contains('AVFoundation'));

      // Permissions
      expect(manifest.permissions.containsKey('camera'), isTrue);
      expect(manifest.permissions['camera']?.androidPermission, 'android.permission.CAMERA');
      expect(manifest.permissions['camera']?.iosPlistKey, 'NSCameraUsageDescription');
      expect(manifest.permissions['camera']?.optional, isFalse);

      expect(manifest.permissions.containsKey('microphone'), isTrue);
      expect(manifest.permissions['microphone']?.optional, isTrue);

      expect(manifest.configPluginClassName, 'BloomCameraConfigPlugin');

      // JSON serialization
      final json = manifest.toJson();
      expect(json['name'], 'bloom_camera');
      expect(json['android']['minSdk'], 24);
    });
  });

  group('Phase 9: Structured Native Exceptions', () {
    test('Instantiates and maps typed exceptions', () {
      final permEx = BloomNativePermissionDeniedException(
        permission: 'camera',
        message: 'User denied camera permission',
      );
      expect(permEx.code, 'PERMISSION_DENIED');
      expect(permEx.permission, 'camera');
      expect(permEx.toString(), contains('BloomNativeException[PERMISSION_DENIED]'));

      final hwEx = BloomNativeHardwareUnavailableException(
        hardware: 'nfc_sensor',
        message: 'NFC chip is not present on this device',
      );
      expect(hwEx.code, 'HARDWARE_UNAVAILABLE');
      expect(hwEx.hardware, 'nfc_sensor');

      final cfgEx = BloomNativeConfigurationException(
        message: 'Missing Google Maps API Key in bloom.yaml',
      );
      expect(cfgEx.code, 'CONFIGURATION_ERROR');

      final opEx = BloomNativeOperationFailedException(
        message: 'Failed to encode image buffer',
      );
      expect(opEx.code, 'OPERATION_FAILED');
    });
  });

  group('Phase 9: BloomModuleRegistry & Lifecycle Coordination', () {
    test('Registers, retrieves, dispatches lifecycle, and resets modules', () async {
      final registry = BloomModuleRegistry();
      await registry.reset();

      expect(registry.moduleCount, 0);

      final cameraModule = MockPlatformCameraModule();
      cameraModule.setConstant('maxZoom', 5.0);

      await registry.registerModule(cameraModule);

      expect(registry.moduleCount, 1);
      expect(registry.hasModule('BloomCamera'), isTrue);
      expect(registry.getModule<MockPlatformCameraModule>('BloomCamera'), same(cameraModule));
      expect(cameraModule.getProperty<double>('maxZoom'), 5.0);

      // Lifecycle dispatch
      expect(cameraModule.resumedCalled, isFalse);
      registry.dispatchLifecycle(BloomLifecycleEvent.resumed);
      expect(cameraModule.resumedCalled, isTrue);

      expect(cameraModule.pausedCalled, isFalse);
      registry.dispatchLifecycle(BloomLifecycleEvent.paused);
      expect(cameraModule.pausedCalled, isTrue);

      // Diagnostic dump
      final dump = registry.dumpRegistry();
      expect(dump['count'], 1);
      expect(dump['modules']['BloomCamera']['name'], 'BloomCamera');
      expect(dump['modules']['BloomCamera']['constants']['maxZoom'], 5.0);

      // Unregister
      await registry.unregisterModule('BloomCamera');
      expect(registry.moduleCount, 0);
      expect(() => registry.getModule('BloomCamera'), throwsStateError);
    });
  });

  group('Phase 9: Native Module Hardware Streaming', () {
    test('Emits and receives events via subscribeStream', () async {
      final module = MockPlatformCameraModule();
      await module.onInit();

      final stream = module.subscribeStream<Map<String, dynamic>>('onFrameCaptured');

      final emittedEvents = <Map<String, dynamic>>[];
      final sub = stream.listen((event) {
        emittedEvents.add(event);
      });

      module.emitEvent('onFrameCaptured', {'frameId': 101, 'bytes': 1024});
      module.emitEvent('onFrameCaptured', {'frameId': 102, 'bytes': 1024});

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emittedEvents.length, 2);
      expect(emittedEvents.first['frameId'], 101);
      expect(emittedEvents.last['frameId'], 102);

      await sub.cancel();
      await module.onDispose();
    });
  });

  group('Phase 9: BloomNativeView Widget', () {
    testWidgets('Renders platform view fallback with props in test environment', (tester) async {
      await tester.pumpWidget(
        const ui.BloomApp(
          home: ui.BloomScaffold(
            body: BloomNativeView(
              viewType: 'BloomCameraPreview',
              props: {
                'lens': 'back',
                'zoom': 2.0,
              },
            ),
          ),
        ),
      );

      expect(find.text('Native Platform View: BloomCameraPreview'), findsOneWidget);
      expect(find.text('Props: {lens: back, zoom: 2.0}'), findsOneWidget);
    });

    testWidgets('Renders custom fallback widget when provided', (tester) async {
      await tester.pumpWidget(
        ui.BloomApp(
          home: ui.BloomScaffold(
            body: BloomNativeView(
              viewType: 'CustomMapView',
              fallback: const Center(
                child: Text('Custom Map Fallback Mock'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Map Fallback Mock'), findsOneWidget);
    });
  });
}
