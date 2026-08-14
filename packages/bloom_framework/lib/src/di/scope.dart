// lib/src/di/scope.dart
import 'container.dart';

class BloomTestOverride<T> {
  final Type type;
  final T instance;

  BloomTestOverride(this.instance) : type = T;
}

/// A scoped DI harness for running unit and widget tests with isolated overrides.
/// Activates an isolated child container as the active container during test execution.
class BloomTestScope {
  final BloomContainer container;
  final BloomContainer _previousContainer;

  BloomTestScope({BloomContainer? parent, List<BloomTestOverride<dynamic>>? overrides})
      : _previousContainer = globalContainer,
        container = BloomContainer(parent: parent ?? globalContainer) {
    if (overrides != null) {
      for (final o in overrides) {
        container.overrideType(o.type, o.instance);
      }
    }
    setActiveContainer(container);
  }

  /// Inject an override into this isolated test scope.
  void override<T>(T mockInstance) {
    container.override<T>(mockInstance);
  }

  /// Resolve dependency within test scope.
  T inject<T>() => container.inject<T>();

  /// Resolve optional dependency within test scope.
  T? injectOrNull<T>() => container.injectOrNull<T>();

  /// Dispose test scope, restore previous container, and clean up local overrides.
  void dispose() {
    container.reset();
    setActiveContainer(_previousContainer);
  }
}
