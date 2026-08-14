// lib/src/di/container.dart
import 'dart:collection';

typedef FactoryFunc<T> = T Function();

enum _BindingType { transient, singleton, value }

class _Binding<T> {
  final _BindingType type;
  final FactoryFunc<T>? factory;
  T? instance;

  _Binding.transient(this.factory) : type = _BindingType.transient;

  _Binding.singleton(this.factory, {bool lazy = true})
      : type = _BindingType.singleton {
    if (!lazy && factory != null) {
      instance = factory!();
    }
  }

  _Binding.value(this.instance)
      : type = _BindingType.value,
        factory = null;

  T resolve() {
    switch (type) {
      case _BindingType.transient:
        return factory!();
      case _BindingType.singleton:
        instance ??= factory!();
        return instance!;
      case _BindingType.value:
        return instance!;
    }
  }
}

/// Lightweight, high-performance Dependency Injection container for Bloom.
class BloomContainer {
  final BloomContainer? parent;
  final Map<Type, _Binding<dynamic>> _bindings = HashMap<Type, _Binding<dynamic>>();
  final Map<Type, dynamic> _overrides = HashMap<Type, dynamic>();

  BloomContainer({this.parent});

  /// Register a transient factory. A new instance is created on each `inject<T>()`.
  void provide<T>(FactoryFunc<T> factory) {
    _bindings[T] = _Binding<T>.transient(factory);
  }

  /// Register a singleton factory. The instance is created once and reused.
  void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) {
    _bindings[T] = _Binding<T>.singleton(factory, lazy: lazy);
  }

  /// Register an existing value instance.
  void provideValue<T>(T value) {
    _bindings[T] = _Binding<T>.value(value);
  }

  /// Override a dependency with a concrete generic type [T].
  void override<T>(T instance) {
    _overrides[T] = instance;
  }

  /// Override a dependency with an explicit [type].
  void overrideType(Type type, dynamic instance) {
    _overrides[type] = instance;
  }

  /// Remove a test override by generic type or explicit [type].
  void removeOverride<T>([Type? type]) {
    _overrides.remove(type ?? T);
  }

  /// Resolve dependency of type [T]. Throws [StateError] if unregistered.
  T inject<T>() {
    if (_overrides.containsKey(T)) {
      return _overrides[T] as T;
    }

    final binding = _bindings[T];
    if (binding != null) {
      return binding.resolve() as T;
    }

    if (parent != null) {
      return parent!.inject<T>();
    }

    throw StateError(
      'BloomContainer: No provider registered for type "$T". '
      'Ensure you called `provide<$T>()` or `provideSingleton<$T>()` before resolving.',
    );
  }

  /// Resolve dependency of type [T], or return `null` if not registered.
  T? injectOrNull<T>() {
    if (_overrides.containsKey(T)) {
      return _overrides[T] as T?;
    }
    final binding = _bindings[T];
    if (binding != null) {
      return binding.resolve() as T;
    }
    if (parent != null) {
      return parent!.injectOrNull<T>();
    }
    return null;
  }

  /// Check if a dependency of type [T] is registered.
  bool has<T>() =>
      _overrides.containsKey(T) ||
      _bindings.containsKey(T) ||
      (parent?.has<T>() ?? false);

  /// Clear all local registrations and overrides.
  void reset() {
    _bindings.clear();
    _overrides.clear();
  }
}

/// Global active container used by the framework.
BloomContainer globalContainer = BloomContainer();

/// Resolve a dependency from the global Bloom container.
T inject<T>() => globalContainer.inject<T>();

/// Resolve a dependency from the global Bloom container, or return `null` if not registered.
T? injectOrNull<T>() => globalContainer.injectOrNull<T>();

/// Register a transient factory on the global Bloom container.
void provide<T>(FactoryFunc<T> factory) => globalContainer.provide<T>(factory);

/// Register a singleton on the global Bloom container.
void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) =>
    globalContainer.provideSingleton<T>(factory, lazy: lazy);

/// Register an existing instance value on the global Bloom container.
void provideValue<T>(T value) => globalContainer.provideValue<T>(value);
