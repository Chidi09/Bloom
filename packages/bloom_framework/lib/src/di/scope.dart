// lib/src/di/scope.dart
import 'container.dart';

class BloomTestOverride<T> {
  final Type type;
  final T instance;

  BloomTestOverride(this.instance) : type = T;
}

/// A scoped DI harness for running unit and widget tests with isolated overrides.
/// Does not mutate the global container; creates an isolated child scope.
class BloomTestScope {
  final BloomContainer container;
  final List<Type> _appliedOverrides = [];

  BloomTestScope({BloomContainer? parent, List<BloomTestOverride<dynamic>>? overrides})
      : container = BloomContainer(parent: parent ?? globalContainer) {
    if (overrides != null) {
      for (final o in overrides) {
        container.override(o.instance);
        _appliedOverrides.add(o.type);
      }
    }
  }

  /// Inject an override into this isolated test scope.
  void override<T>(T mockInstance) {
    container.override<T>(mockInstance);
    _appliedOverrides.add(T);
  }

  /// Resolve dependency within test scope.
  T inject<T>() => container.inject<T>();

  /// Resolve optional dependency within test scope.
  T? injectOrNull<T>() => container.injectOrNull<T>();

  /// Dispose test scope and clean up local overrides.
  void dispose() {
    for (final type in _appliedOverrides) {
      container.removeOverride(type);
    }
    _appliedOverrides.clear();
    container.reset();
  }
}
