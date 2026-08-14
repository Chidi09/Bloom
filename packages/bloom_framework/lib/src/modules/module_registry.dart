// lib/src/modules/module_registry.dart
import 'dart:async';
import 'native_module.dart';

/// Application lifecycle events forwarded to registered Bloom Native Modules.
enum BloomLifecycleEvent {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

/// Central registry managing the lifecycle, registration, and discovery of Bloom Native Modules.
class BloomModuleRegistry {
  static final BloomModuleRegistry _instance = BloomModuleRegistry._internal();
  factory BloomModuleRegistry() => _instance;
  BloomModuleRegistry._internal();

  final Map<String, BloomNativeModule> _modules = {};
  final StreamController<BloomLifecycleEvent> _lifecycleStream = StreamController<BloomLifecycleEvent>.broadcast();

  /// Total number of active registered modules.
  int get moduleCount => _modules.length;

  /// Registers a native module and initializes its runtime hooks.
  Future<void> registerModule(BloomNativeModule module) async {
    _modules[module.name] = module;
    await module.onInit();
  }

  /// Unregisters and disposes a native module by name.
  Future<void> unregisterModule(String name) async {
    final module = _modules.remove(name);
    if (module != null) {
      await module.onDispose();
    }
  }

  /// Retrieves a registered module by name, or throws [StateError] if missing.
  T getModule<T extends BloomNativeModule>(String name) {
    final module = _modules[name];
    if (module == null) {
      throw StateError('Bloom Native Module "$name" is not registered in BloomModuleRegistry.');
    }
    return module as T;
  }

  /// Retrieves an optional registered module by name, returning null if missing.
  T? getModuleOrNull<T extends BloomNativeModule>(String name) {
    return _modules[name] as T?;
  }

  /// Checks if a module is registered.
  bool hasModule(String name) => _modules.containsKey(name);

  /// Returns an unmodifiable list of all active modules.
  List<BloomNativeModule> getAllModules() => List.unmodifiable(_modules.values);

  /// Forwards an application lifecycle transition to all registered native modules.
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

  /// Completely clears and resets all registered modules (used between test runs).
  Future<void> reset() async {
    for (final module in _modules.values) {
      await module.onDispose();
    }
    _modules.clear();
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
