# Phase 9: Bloom Native Module Platform & DSL

> **Objective:** Transform Bloom into an extensible ecosystem platform by providing a declarative, typed native module authoring system and code generator for Dart ↔ Swift/Kotlin, eliminating manual platform-channel boilerplate.

---

## 🏗️ Architecture & Component Topology

```text
               @BloomModule (Dart DSL)
                         │
                         ▼
             Bloom Module Code Generator
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
 Dart Bridge API   Swift Bridge     Kotlin Bridge
  (Type-Safe)     (iOS / macOS)    (Android Engine)
        │                │                │
        └────────────────┼────────────────┘
                         ▼
            Bloom Autolinking & Prebuild
```

---

## 📦 1. Public Module Authoring API & Scaffolding

### CLI Command: `bloom create module`
Scaffolds a standalone, publishable Bloom Native Module:

```bash
bloom create module bloom_camera
```

### Generated Module Anatomy
```text
bloom_camera/
├── lib/
│   ├── bloom_camera.dart              # Public Dart API surface
│   └── src/
│       ├── bloom_camera.module.dart   # Declarative @BloomModule definition
│       └── bloom_camera.g.dart        # Auto-generated typed bridge bindings
├── android/
│   ├── build.gradle.kts
│   └── src/main/kotlin/dev/bloom/camera/
│       ├── BloomCameraModule.kt       # Native Kotlin module implementation
│       └── BloomCameraView.kt         # Native Android View (CameraX preview)
├── ios/
│   ├── BloomCamera.podspec
│   └── Sources/
│       ├── BloomCameraModule.swift    # Native Swift module implementation
│       └── BloomCameraView.swift      # Native iOS UIView (AVFoundation preview)
├── bloom.module.yaml                  # Module manifest (permissions, capabilities, hooks)
├── test/                              # Unit & mock tests
└── README.md
```

---

## 📝 2. Declarative Native Module DSL (`@BloomModule`)

Authors declare the contract in Dart using metadata annotations:

```dart
// lib/src/bloom_camera.module.dart
import 'package:bloom_framework/bloom_modules.dart';

@BloomModule(
  name: 'BloomCamera',
  version: '1.0.0',
)
abstract class BloomCameraDefinition {
  // Properties & Constants
  @BloomConstant()
  List<String> get supportedResolutions;

  // Async Methods with Typed Arguments
  @BloomAsyncFunction(thread: NativeThread.background)
  Future<CameraCaptureResult> takePicture({
    required CameraQuality quality,
    bool enableFlash = false,
  });

  // Long-Running Events
  @BloomEvent()
  Stream<CameraStatusEvent> get onCameraStatusChanged;

  // Long-Running Hardware Streams
  @BloomStream()
  Stream<CameraFrameData> get frameStream;

  // Native Views
  @BloomView(name: 'BloomCameraPreview')
  Widget preview({
    required CameraLensDirection lens,
    double zoomLevel = 1.0,
    void Function(CameraReadyEvent)? onCameraReady,
  });

  // Native Lifecycle Hooks
  @BloomLifecycleHook()
  void onHostResume();

  @BloomLifecycleHook()
  void onHostPause();
}
```

---

## ⚡ 3. Type-Safe Native Function & Argument Binding

The Bloom code generator automatically compiles the `@BloomModule` contract into typed Dart, Swift, and Kotlin interfaces, validating arguments at the boundary:

### Supported Typed Arguments
* Primitive types: `String`, `int`, `double`, `bool`, `DateTime`
* Collections: `List<T>`, `Map<String, V>`
* Nullable fields & default values
* Strongly typed Dart Enums ➔ Swift/Kotlin Enums
* Structured JSON Data Models (automatically serialized/deserialized)
* Raw Binary Data: `Uint8List` ➔ `Data` (Swift) / `ByteArray` (Kotlin)

### Generated Swift Bridge Interface
```swift
// ios/Sources/BloomCameraModule.swift
import Foundation
import BloomModuleCore

public class BloomCameraModule: BloomNativeModule {
    public override func definition() -> ModuleDefinition {
        Name("BloomCamera")
        
        Constants([
            "supportedResolutions": ["720p", "1080p", "4k"]
        ])
        
        AsyncFunction("takePicture", on: .backgroundQueue) { (quality: String, enableFlash: Bool, promise: Promise) in
            // Native AVFoundation logic
            let result = self.capturePhoto(quality: quality, flash: enableFlash)
            promise.resolve(result.toMap())
        }
        
        Event("onCameraStatusChanged")
        Stream("frameStream")
    }
}
```

### Generated Kotlin Bridge Interface
```kotlin
// android/src/main/kotlin/dev/bloom/camera/BloomCameraModule.kt
package dev.bloom.camera

import dev.bloom.modules.BloomNativeModule
import dev.bloom.modules.ModuleDefinition
import dev.bloom.modules.NativeThread

class BloomCameraModule : BloomNativeModule() {
    override fun definition(): ModuleDefinition = moduleDefinition {
        name("BloomCamera")
        
        constants(
            "supportedResolutions" to listOf("720p", "1080p", "4k")
        )
        
        asyncFunction("takePicture", NativeThread.BACKGROUND) { quality: String, enableFlash: Boolean ->
            // Native CameraX capture logic
            capturePhoto(quality, enableFlash)
        }
        
        event("onCameraStatusChanged")
        stream("frameStream")
    }
}
```

---

## 🖼️ 4. Native Views & Props (`BloomNativeView`)

Modules can register hardware-accelerated platform views (maps, camera viewfinders, video players, web views) with declarative property binding:

```dart
// Dart Consumer View
class CameraScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BloomNativeView(
      viewType: 'BloomCameraPreview',
      props: {
        'lens': 'back',
        'zoomLevel': 1.5,
      },
      onEvent: (eventName, payload) {
        if (eventName == 'onCameraReady') {
          print('Camera sensor active: $payload');
        }
      },
    );
  }
}
```

---

## 🧵 5. Native Threading & Queue Semantics

Native operations declare their execution thread to prevent blocking the UI thread:

```dart
enum NativeThread {
  ui,              // Main UI thread (view manipulations)
  background,      // Concurrent background worker queue
  io,              // High-throughput disk/network IO queue
  customExecutor,  // Dedicated serial dispatch queue
}
```

---

## 🚨 6. Structured Native Error Mapping

Exceptions thrown in Swift or Kotlin are converted into strongly typed Dart exception hierarchies:

```dart
try {
  await camera.takePicture(quality: CameraQuality.ultraHd);
} on BloomNativePermissionDeniedException catch (e) {
  logger.warn('Permission denied: ${e.permission}');
} on BloomNativeHardwareUnavailableException catch (e) {
  logger.error('Camera sensor busy or hardware fault: ${e.message}');
} on BloomNativeException catch (e) {
  logger.error('Generic platform error [${e.code}]: ${e.message}');
}
```

---

## 📄 7. Module Manifest (`bloom.module.yaml`)

Every module declares its platform requirements, permissions, and prebuild transformation hooks:

```yaml
# bloom.module.yaml
name: bloom_camera
version: 1.0.0
description: "High-performance camera module for Bloom applications."

platforms:
  android:
    min_sdk: 24
    dependencies:
      - "androidx.camera:camera-camera2:1.3.1"
      - "androidx.camera:camera-lifecycle:1.3.1"
      - "androidx.camera:camera-view:1.3.1"
  ios:
    min_version: "15.0"
    frameworks:
      - AVFoundation
      - CoreMedia

permissions:
  camera:
    android: "android.permission.CAMERA"
    ios: "NSCameraUsageDescription"
    default_prompt: "Allow camera access to capture photos and scan QR codes."
  microphone:
    android: "android.permission.RECORD_AUDIO"
    ios: "NSMicrophoneUsageDescription"
    optional: true

config_plugin:
  class_name: BloomCameraConfigPlugin
```

---

## 🧪 Verification & Acceptance Criteria

1. Running `bloom create module <name>` generates a complete, compilable Dart + Swift + Kotlin package structure.
2. The `@BloomModule` code generator produces typed bindings without manual `MethodChannel` / `EventChannel` string invocations.
3. Native views (`BloomNativeView`) mount correctly on Android (`AndroidView`) and iOS (`UiKitView`) with reactive prop updates.
4. Native errors in Swift (`NSError` / `Error`) and Kotlin (`Exception`) map deterministically to `BloomNativeException` classes in Dart.
