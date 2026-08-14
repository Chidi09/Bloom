// lib/src/di/scope.dart
import 'container.dart';

/// A scoped DI harness for running unit and widget tests with isolated overrides.
class BloomTestScope {
  final BloomContainer container;
  final List<Type> _appliedOverrides = [];

  BloomTestScope({BloomContainer? parent})
      : container = parent ?? BloomContainer();

  /// Inject an override into this test scope.
  void override<T>(T mockInstance) {
    container.override<T>(mockInstance);
    _appliedOverrides.add(T);
  }

  /// Resolve dependency within test scope.
  T inject<T>() => container.inject<T>();

  /// Resolve optional dependency within test scope.
  T? injectOrNull<T>() => container.injectOrNull<T>();

  /// Dispose test scope and clean up overrides.
  void dispose() {
    for (final type in _appliedOverrides) {
      container.removeOverride();
    }
    _appliedOverrides.clear();
  }
}
