// lib/src/modules/annotations.dart

/// Execution thread model for native module operations.
enum NativeThread {
  /// Main UI thread. Required for direct view and layout manipulations.
  ui,

  /// Concurrent background worker queue (DispatchQueue.global / Coroutine Dispatchers.Default).
  background,

  /// High-throughput I/O queue (DispatchQueue.io / Dispatchers.IO).
  io,

  /// Dedicated serial dispatch queue ensuring FIFO order.
  customExecutor,
}

/// Metadata annotation declaring a Bloom Native Module.
class BloomModule {
  /// The unique module identifier (e.g. 'BloomCamera', 'BloomLocation').
  final String name;

  /// Semantic version of the module contract.
  final String version;

  /// Human-readable module description.
  final String description;

  const BloomModule({
    required this.name,
    this.version = '1.0.0',
    this.description = '',
  });
}

/// Metadata annotation declaring a static constant exported by the native platform.
class BloomConstant {
  /// Custom constant key name override.
  final String? name;

  /// Creates a [BloomConstant] annotation with optional name override.
  const BloomConstant([this.name]);
}

/// Metadata annotation declaring an asynchronous native function bridge.
class BloomAsyncFunction {
  /// Execution thread queue on the host platform.
  final NativeThread thread;

  /// Custom native method name override.
  final String? name;

  /// Creates a [BloomAsyncFunction] annotation.
  const BloomAsyncFunction({
    this.thread = NativeThread.ui,
    this.name,
  });
}

/// Metadata annotation declaring a fast synchronous native function bridge.
class BloomSyncFunction {
  /// Custom native method name override.
  final String? name;

  /// Creates a [BloomSyncFunction] annotation with optional name override.
  const BloomSyncFunction([this.name]);
}

/// Metadata annotation declaring a native event listener.
class BloomEvent {
  /// Custom native event name override.
  final String? name;

  /// Creates a [BloomEvent] annotation with optional name override.
  const BloomEvent([this.name]);
}

/// Metadata annotation declaring a continuous native hardware stream.
class BloomStream {
  /// Custom native stream name override.
  final String? name;

  /// Creates a [BloomStream] annotation with optional name override.
  const BloomStream([this.name]);
}

/// Metadata annotation declaring a native platform view (e.g. Camera preview, Map, AR view).
class BloomView {
  /// Native platform view identifier registered with the host platform view factory.
  final String name;

  /// Creates a [BloomView] annotation for platform view [name].
  const BloomView({required this.name});
}

/// Metadata annotation declaring a host application lifecycle listener.
class BloomLifecycleHook {
  /// Creates a [BloomLifecycleHook] annotation.
  const BloomLifecycleHook();
}
