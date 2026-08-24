// lib/src/modules/native_module.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'annotations.dart';
import 'exceptions.dart';

/// Base class for all native Bloom modules bridging Dart to host iOS/Android platforms.
///
/// Encapsulates platform channel dispatching, synchronous state cache,
/// long-running hardware event streams, typed exception translation, and lifecycle notifications.
///
/// Example:
/// ```dart
/// class BloomDeviceModule extends BloomNativeModule {
///   BloomDeviceModule() : super(name: 'BloomDevice');
///
///   Future<String> getDeviceModel() async {
///     final result = await invokeAsync<String>('getDeviceModel');
///     return result ?? 'Unknown';
///   }
/// }
/// ```
abstract class BloomNativeModule {
  /// The unique module name identifier (e.g. `'BloomCamera'`, `'BloomLocation'`).
  final String name;

  /// Semantic version of the native module contract (defaults to `'1.0.0'`).
  final String version;
  MethodChannel? _methodChannel;
  EventChannel? _eventChannel;
  final Map<String, StreamController<dynamic>> _streamControllers = {};
  final Map<String, StreamSubscription<dynamic>> _nativeSubscriptions = {};
  final Map<String, dynamic> _constants = {};
  bool _isInitialized = false;

  /// Creates a [BloomNativeModule] instance.
  ///
  /// Automatically configures underlying [MethodChannel] (`'dev.bloom.modules/$name'`)
  /// and [EventChannel] (`'dev.bloom.modules/$name/events'`) unless custom channels are provided.
  BloomNativeModule({
    required this.name,
    this.version = '1.0.0',
    MethodChannel? customMethodChannel,
    EventChannel? customEventChannel,
  }) {
    _methodChannel = customMethodChannel ?? MethodChannel('dev.bloom.modules/$name');
    _eventChannel = customEventChannel ?? EventChannel('dev.bloom.modules/$name/events');
  }

  /// Underlying method channel for dispatching calls to the host platform.
  MethodChannel? get methodChannel => _methodChannel;

  /// Underlying event channel for streaming continuous events from the host platform.
  EventChannel? get eventChannel => _eventChannel;

  /// Whether the module is initialized and ready for platform calls.
  bool get isInitialized => _isInitialized;

  /// Cached static constants provided by the native platform.
  Map<String, dynamic> get constants => Map.unmodifiable(_constants);

  /// Invoked when the module is registered into [BloomModuleRegistry].
  ///
  /// Subclasses may override this method to perform asynchronous initialization,
  /// query host constants, or acquire native resources.
  Future<void> onInit() async {
    _isInitialized = true;
  }

  /// Invoked when the host application resumes from background into foreground.
  void onHostResume() {}

  /// Invoked when the host application transitions to background.
  void onHostPause() {}

  /// Invoked when the module is unregistered from the registry or explicitly disposed.
  ///
  /// Cancels all active event stream subscriptions and closes stream controllers.
  Future<void> onDispose() async {
    for (final sub in _nativeSubscriptions.values) {
      await sub.cancel();
    }
    _nativeSubscriptions.clear();

    for (final controller in _streamControllers.values) {
      await controller.close();
    }
    _streamControllers.clear();
    _isInitialized = false;
  }

  /// Invokes an asynchronous native method across the platform boundary.
  ///
  /// Maps raw platform errors into typed [BloomNativeException] variants
  /// ([BloomNativePermissionDeniedException], [BloomNativeHardwareUnavailableException], etc.).
  ///
  /// Example:
  /// ```dart
  /// final result = await invokeAsync<Map<String, dynamic>>('fetchDetails', {'id': 42});
  /// ```
  Future<T?> invokeAsync<T>(
    String method, [
    Map<String, dynamic>? args,
    NativeThread thread = NativeThread.ui,
  ]) async {
    try {
      final result = await _methodChannel?.invokeMethod<T>(
        method,
        args,
      );
      return result;
    } on PlatformException catch (e, stack) {
      throw _mapPlatformException(e, stack);
    } catch (e, stack) {
      if (e is BloomNativeException) rethrow;
      throw BloomNativeOperationFailedException(
        message: 'Native call "$name.$method" failed: $e',
        details: args,
        stackTrace: stack,
      );
    }
  }

  /// Synchronously returns a locally cached property or constant.
  ///
  /// Example:
  /// ```dart
  /// final maxQuality = getProperty<int>('MAX_QUALITY') ?? 100;
  /// ```
  T? getProperty<T>(String key) {
    return _constants[key] as T?;
  }

  /// Sets a local constant or cached property in this module.
  void setConstant(String key, dynamic value) {
    _constants[key] = value;
  }

  /// Subscribes to a long-running native hardware stream or event channel.
  ///
  /// Returns a broadcast [Stream] emitting typed data [T] from the host platform.
  ///
  /// Example:
  /// ```dart
  /// final locationStream = subscribeStream<Map<String, double>>('onLocationUpdate');
  /// ```
  Stream<T> subscribeStream<T>(String streamName, [Map<String, dynamic>? args]) {
    if (!_streamControllers.containsKey(streamName)) {
      final controller = StreamController<dynamic>.broadcast();
      _streamControllers[streamName] = controller;

      // Wire real native EventChannel if available
      if (_eventChannel != null) {
        try {
          final nativeStream = _eventChannel!.receiveBroadcastStream({
            'stream': streamName,
            if (args != null) ...args,
          });

          final sub = nativeStream.listen(
            (event) {
              if (!controller.isClosed) {
                controller.add(event);
              }
            },
            onError: (err, stack) {
              if (!controller.isClosed) {
                if (err is PlatformException) {
                  controller.addError(_mapPlatformException(err, stack));
                } else {
                  controller.addError(err, stack);
                }
              }
            },
          );
          _nativeSubscriptions[streamName] = sub;
        } catch (_) {
          // Native channel unavailable (e.g. test harness / mock mode)
        }
      }
    }

    final controller = _streamControllers[streamName]!;
    return controller.stream.cast<T>();
  }

  /// Emits an event from native callback or test mock into the stream.
  ///
  /// Useful for simulating native hardware events in automated unit and widget tests.
  void emitEvent(String streamName, dynamic payload) {
    if (_streamControllers.containsKey(streamName)) {
      _streamControllers[streamName]?.add(payload);
    }
  }

  /// Maps a raw Flutter [PlatformException] into a typed [BloomNativeException].
  BloomNativeException _mapPlatformException(PlatformException e, StackTrace stack) {
    final code = e.code.toUpperCase();
    if (code.contains('PERMISSION') || code == 'PERMISSION_DENIED') {
      return BloomNativePermissionDeniedException(
        permission: (e.details is Map ? (e.details as Map)['permission']?.toString() : null) ?? name,
        message: e.message ?? 'Permission denied for module $name',
        details: e.details,
      );
    }
    if (code.contains('HARDWARE') || code.contains('UNAVAILABLE') || code == 'DEVICE_NOT_FOUND') {
      return BloomNativeHardwareUnavailableException(
        hardware: (e.details is Map ? (e.details as Map)['hardware']?.toString() : null) ?? name,
        message: e.message ?? 'Hardware unavailable for module $name',
        details: e.details,
      );
    }
    if (code.contains('CONFIG') || code == 'INVALID_CONFIGURATION') {
      return BloomNativeConfigurationException(
        message: e.message ?? 'Invalid native configuration for module $name',
        details: e.details,
      );
    }

    return BloomNativeOperationFailedException(
      message: e.message ?? 'Native operation failed in module $name',
      details: e.details,
      stackTrace: stack,
    );
  }
}
