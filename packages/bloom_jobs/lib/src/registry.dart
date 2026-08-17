import 'task.dart';

/// Single source of truth registry for named task handlers.
///
/// Mirrors `TaskRegistration` / compile-time inventory from `djangors-tasks`.
class BloomTaskRegistry {
  final Map<String, BloomTaskHandler> _handlers = {};

  /// Registers a task handler function for the given [taskName].
  ///
  /// Throws [StateError] if a handler is already registered for [taskName].
  void register(String taskName, BloomTaskHandler handler) {
    if (_handlers.containsKey(taskName)) {
      throw StateError('Task handler for "$taskName" is already registered.');
    }
    _handlers[taskName] = handler;
  }

  /// Registers or overwrites a task handler function for the given [taskName].
  void registerOrReplace(String taskName, BloomTaskHandler handler) {
    _handlers[taskName] = handler;
  }

  /// Looks up a registered task handler by [taskName], returning null if not found.
  BloomTaskHandler? get(String taskName) => _handlers[taskName];

  /// Checks if a task handler is registered for [taskName].
  bool has(String taskName) => _handlers.containsKey(taskName);

  /// Unregisters the handler for [taskName].
  void unregister(String taskName) {
    _handlers.remove(taskName);
  }

  /// List all registered task names.
  List<String> get registeredTaskNames => List.unmodifiable(_handlers.keys);

  /// Clears all registered task handlers.
  void clear() {
    _handlers.clear();
  }
}
