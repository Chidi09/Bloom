// lib/src/modules/annotations.dart

/// Execution thread model for native module operations on host platforms (iOS/Android).
///
/// Directs the host bridge runtime to execute the corresponding native method
/// on the designated dispatch queue or thread pool.
///
/// Example:
/// ```dart
/// @BloomAsyncFunction(thread: NativeThread.io)
/// Future<String> readBigFile(String path) => invokeAsync('readBigFile', {'path': path});
/// ```
enum NativeThread {
  /// Main UI thread. Required for direct view, window, and layout manipulations.
  ui,

  /// Concurrent background worker queue (`DispatchQueue.global()` on iOS, `Dispatchers.Default` on Android).
  background,

  /// High-throughput I/O queue (`DispatchQueue.io` on iOS, `Dispatchers.IO` on Android).
  io,

  /// Dedicated serial dispatch queue ensuring strict FIFO execution order.
  customExecutor,
}

/// Metadata annotation declaring a Bloom Native Module.
///
/// Attached to classes extending `BloomNativeModule` to identify the module contract,
/// version, and human-readable metadata for the Bloom registry and code generators.
///
/// Example:
/// ```dart
/// @BloomModule(name: 'BloomLocation', version: '1.2.0', description: 'GPS location tracking module')
/// class BloomLocationModule extends BloomNativeModule {
///   BloomLocationModule() : super(name: 'BloomLocation');
/// }
/// ```
class BloomModule {
  /// The unique module identifier (e.g. `'BloomCamera'`, `'BloomLocation'`).
  final String name;

  /// Semantic version of the module contract (defaults to `'1.0.0'`).
  final String version;

  /// Human-readable module description.
  final String description;

  /// Creates a [BloomModule] annotation.
  const BloomModule({
    required this.name,
    this.version = '1.0.0',
    this.description = '',
  });
}

/// Metadata annotation declaring a static constant exported by the host native platform.
///
/// Instructs the code generator or runtime to expose synchronous host constants
/// into the module's cached constant registry.
///
/// Example:
/// ```dart
/// @BloomConstant('DEVICE_MODEL')
/// String? get deviceModel => getProperty<String>('DEVICE_MODEL');
/// ```
class BloomConstant {
  /// Custom constant key name override. When omitted, the field name is used.
  final String? name;

  /// Creates a [BloomConstant] annotation with an optional custom key [name] override.
  const BloomConstant([this.name]);
}

/// Metadata annotation declaring an asynchronous native function bridge.
///
/// Specifies the target [thread] execution model and optional platform method [name].
///
/// Example:
/// ```dart
/// @BloomAsyncFunction(thread: NativeThread.background, name: 'compressImage')
/// Future<String> compress(String path, int quality) =>
///     invokeAsync('compressImage', {'path': path, 'quality': quality});
/// ```
class BloomAsyncFunction {
  /// Execution thread queue on the host platform (defaults to [NativeThread.ui]).
  final NativeThread thread;

  /// Custom native method name override. When omitted, the Dart method name is used.
  final String? name;

  /// Creates a [BloomAsyncFunction] annotation.
  const BloomAsyncFunction({
    this.thread = NativeThread.ui,
    this.name,
  });
}

/// Metadata annotation declaring a fast synchronous native function bridge.
///
/// Synchronous bridges execute directly across JNI/C-FFI without asynchronous message passing.
///
/// Example:
/// ```dart
/// @BloomSyncFunction('getSystemUptime')
/// int get uptime => getProperty<int>('uptime') ?? 0;
/// ```
class BloomSyncFunction {
  /// Custom native method name override.
  final String? name;

  /// Creates a [BloomSyncFunction] annotation with optional [name] override.
  const BloomSyncFunction([this.name]);
}

/// Metadata annotation declaring a native event listener.
///
/// Example:
/// ```dart
/// @BloomEvent('onOrientationChange')
/// void handleOrientation(String orientation) {}
/// ```
class BloomEvent {
  /// Custom native event name override.
  final String? name;

  /// Creates a [BloomEvent] annotation with optional [name] override.
  const BloomEvent([this.name]);
}

/// Metadata annotation declaring a continuous native hardware stream.
///
/// Binds a long-running sensor or peripheral event channel to a Dart [Stream].
///
/// Example:
/// ```dart
/// @BloomStream('accelerometer')
/// Stream<Map<String, double>> get accelerometer => subscribeStream('accelerometer');
/// ```
class BloomStream {
  /// Custom native stream name override.
  final String? name;

  /// Creates a [BloomStream] annotation with optional [name] override.
  const BloomStream([this.name]);
}

/// Metadata annotation declaring a native platform view (e.g. Camera preview, Map, AR view).
///
/// Links the Dart widget wrapper to the host platform view factory registered under [name].
///
/// Example:
/// ```dart
/// @BloomView(name: 'BloomCameraView')
/// class CameraPreviewWidget extends StatelessWidget { ... }
/// ```
class BloomView {
  /// Native platform view identifier registered with the host platform view factory.
  final String name;

  /// Creates a [BloomView] annotation for platform view [name].
  const BloomView({required this.name});
}

/// Metadata annotation declaring a host application lifecycle listener.
///
/// Methods annotated with `@BloomLifecycleHook()` receive lifecycle transitions (resumed, paused, detached).
///
/// Example:
/// ```dart
/// @BloomLifecycleHook()
/// void onHostPause() {
///   // Release hardware locks
/// }
/// ```
class BloomLifecycleHook {
  /// Creates a [BloomLifecycleHook] annotation.
  const BloomLifecycleHook();
}
