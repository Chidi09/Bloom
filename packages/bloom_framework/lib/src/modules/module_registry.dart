// lib/src/modules/module_registry.dart
import 'dart:async';
import 'native_module.dart';

/// Application lifecycle events forwarded to registered Bloom Native Modules.
///
/// Mirrors Flutter and host OS application lifecycle transitions.
///
/// Example:
/// ```dart
/// BloomModuleRegistry().dispatchLifecycle(BloomLifecycleEvent.resumed);
/// ```
enum BloomLifecycleEvent {
  /// App entered foreground and is visible and interactive.
  resumed,

  /// App became inactive and is not receiving user input.
  inactive,

  /// App entered background and is in a paused state.
  paused,

  /// App view is detached from host view hierarchy.
  detached,

  /// App views are hidden from display.
  hidden,
}

/// Central singleton registry managing the lifecycle, registration, and discovery of Bloom Native Modules.
///
/// Modules register on startup or on demand, and automatically receive application lifecycle
/// notifications ([BloomLifecycleEvent.resumed], [BloomLifecycleEvent.paused]) dispatched by the host.
///
/// Example:
/// ```dart
/// final registry = BloomModuleRegistry();
/// await registry.registerModule(myCameraModule);
/// final camera = registry.getModule<CameraModule>('BloomCamera');
/// ```
class BloomModuleRegistry {
  static final BloomModuleRegistry _instance = BloomModuleRegistry._internal();

  /// Returns the singleton [BloomModuleRegistry] instance.
  factory BloomModuleRegistry() => _instance;
  BloomModuleRegistry._internal();

  final Map<String, BloomNativeModule> _modules = {};
  final StreamController<BloomLifecycleEvent> _lifecycleStream = StreamController<BloomLifecycleEvent>.broadcast();

  /// Total number of active registered modules in this registry.
  int get moduleCount => _modules.length;

  /// Registers a native [module] and executes its asynchronous [BloomNativeModule.onInit] lifecycle hook.
  ///
  /// Example:
  /// ```dart
  /// await BloomModuleRegistry().registerModule(myModule);
  /// ```
  Future<void> registerModule(BloomNativeModule module) async {
    _modules[module.name] = module;
    await module.onInit();
  }

  /// Unregisters and disposes a native module identified by [name], invoking [BloomNativeModule.onDispose].
  ///
  /// Example:
  /// ```dart
  /// await BloomModuleRegistry().unregisterModule('BloomCamera');
  /// ```
  Future<void> unregisterModule(String name) async {
    final module = _modules.remove(name);
    if (module != null) {
      await module.onDispose();
    }
  }

  /// Retrieves a registered module by [name], or throws [StateError] if missing.
  ///
  /// Example:
  /// ```dart
  /// final camera = BloomModuleRegistry().getModule<BloomCameraModule>('BloomCamera');
  /// ```
  T getModule<T extends BloomNativeModule>(String name) {
    final module = _modules[name];
    if (module == null) {
      throw StateError('Bloom Native Module "$name" is not registered in BloomModuleRegistry.');
    }
    return module as T;
  }

  /// Retrieves an optional registered module by [name], returning `null` if not registered.
  ///
  /// Example:
  /// ```dart
  /// final location = BloomModuleRegistry().getModuleOrNull<LocationModule>('BloomLocation');
  /// if (location != null) {
  ///   // use location module
  /// }
  /// ```
  T? getModuleOrNull<T extends BloomNativeModule>(String name) {
    return _modules[name] as T?;
  }

  /// Checks whether a module identified by [name] is currently registered.
  bool hasModule(String name) => _modules.containsKey(name);

  /// Returns an unmodifiable list of all currently active registered modules.
  List<BloomNativeModule> getAllModules() => List.unmodifiable(_modules.values);

  /// Forwards an application lifecycle transition [event] to all registered native modules.
  ///
  /// Calls [BloomNativeModule.onHostResume] when [event] is [BloomLifecycleEvent.resumed],
  /// and [BloomNativeModule.onHostPause] when [event] is [BloomLifecycleEvent.paused].
  void dispatchLifecycle(BloomLifecycleEvent event) {
    _lifecycleStream.add(event);
    for (final module in _modules.values) {
      if (event == BloomLifecycleEvent.resumed) {
        module.onHostResume();
      } else if (event == BloomLifecycleEvent.paused) {
        module.onHostPause();
      }
    }
  }

  /// Synchronously resets all registered modules and triggers asynchronous background disposal.
  void resetSync() {
    final modulesToDispose = List<BloomNativeModule>.from(_modules.values);
    _modules.clear();
    for (final module in modulesToDispose) {
      unawaited(module.onDispose());
    }
  }

  /// Completely clears and resets all registered modules, awaiting [BloomNativeModule.onDispose] on each.
  ///
  /// Used primarily between unit and widget test runs to ensure isolation.
  Future<void> reset() async {
    final modulesToDispose = List<BloomNativeModule>.from(_modules.values);
    _modules.clear();
    for (final module in modulesToDispose) {
      await module.onDispose();
    }
  }

  /// Dumps metadata of all registered modules for DevTools and diagnostics.
  Map<String, dynamic> dumpRegistry() {
    return {
      'count': _modules.length,
      'modules': _modules.map((key, value) => MapEntry(key, {
            'name': value.name,
            'version': value.version,
            'isInitialized': value.isInitialized,
            'constants': value.constants,
          })),
    };
  }
}
