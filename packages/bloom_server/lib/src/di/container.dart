// lib/src/di/container.dart
import 'dart:collection';

/// Factory function callback that instantiates a dependency of type [T].
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
///
/// ### Architecture & Scoping Model
/// [BloomContainer] supports three binding lifecycles:
/// 1. **Transient** ([provide]): The factory is executed every time [inject] is called,
///    producing a fresh instance each time.
/// 2. **Singleton** ([provideSingleton]): The factory is executed once, and the resulting
///    instance is cached and reused across all subsequent [inject] calls. Can be created
///    lazily on first resolution (default) or eagerly upon registration (`lazy: false`).
/// 3. **Value** ([provideValue]): An already-instantiated object is registered directly.
///
/// ### Hierarchical Resolution
/// Containers can be nested with an optional [parent]. When resolving a type [T]:
/// 1. The container checks for local test overrides ([override] / [overrideType]).
/// 2. The container checks its own local bindings.
/// 3. If not found locally and [parent] exists, resolution delegates up to the [parent].
/// 4. If nowhere found, [inject] throws a descriptive [StateError] (or [injectOrNull] returns `null`).
///
/// ### Testing & Overrides
/// Test harnesses can register overrides via [override] or [BloomTestScope] that take
/// precedence over existing bindings without altering production container setup.
///
/// ### Example
/// ```dart
/// final container = BloomContainer();
///
/// // Register services
/// container.provideSingleton<DatabaseService>(() => PostgresService());
/// container.provide<UserRepository>(() => UserRepository(container.inject<DatabaseService>()));
/// container.provideValue<String>('https://api.example.com');
///
/// // Resolve dependencies
/// final userRepo = container.inject<UserRepository>();
/// ```
class BloomContainer {
  /// Optional parent container for hierarchical dependency lookup cascades.
  final BloomContainer? parent;
  final Map<Type, _Binding<dynamic>> _bindings =
      HashMap<Type, _Binding<dynamic>>();
  final Map<Type, dynamic> _overrides = HashMap<Type, dynamic>();

  /// Creates a [BloomContainer] with an optional [parent] container.
  BloomContainer({this.parent});

  /// Registers a transient [factory] for type [T].
  ///
  /// A new instance is constructed on every call to [inject] or [injectOrNull].
  ///
  /// ### Example
  /// ```dart
  /// container.provide<RandomGenerator>(() => RandomGenerator());
  /// ```
  void provide<T>(FactoryFunc<T> factory) {
    _bindings[T] = _Binding<T>.transient(factory);
  }

  /// Registers a singleton [factory] for type [T].
  ///
  /// The [factory] creates a single instance that is cached and returned for all
  /// future resolutions of [T].
  ///
  /// If [lazy] is `true` (the default), the instance is created on first [inject].
  /// If [lazy] is `false`, the instance is instantiated immediately upon registration.
  ///
  /// ### Example
  /// ```dart
  /// container.provideSingleton<AuthService>(() => AuthService(), lazy: true);
  /// ```
  void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) {
    _bindings[T] = _Binding<T>.singleton(factory, lazy: lazy);
  }

  /// Registers an existing [value] instance for type [T].
  ///
  /// Useful for configuration objects, pre-constructed clients, or constant values.
  ///
  /// ### Example
  /// ```dart
  /// container.provideValue<AppConfig>(loadedConfig);
  /// ```
  void provideValue<T>(T value) {
    _bindings[T] = _Binding<T>.value(value);
  }

  /// Overrides dependency resolution for generic type [T] with a mock/stub [instance].
  ///
  /// Overrides take highest precedence in resolution, superseding any registered bindings.
  ///
  /// ### Example
  /// ```dart
  /// container.override<EmailService>(MockEmailService());
  /// ```
  void override<T>(T instance) {
    _overrides[T] = instance;
  }

  /// Overrides dependency resolution for an explicit runtime [type] with [instance].
  ///
  /// Useful for dynamic or reflection-free runtime override registration.
  void overrideType(Type type, dynamic instance) {
    _overrides[type] = instance;
  }

  /// Removes an active test override for type [T] (or explicitly specified [type]).
  void removeOverride<T>([Type? type]) {
    _overrides.remove(type ?? T);
  }

  /// Resolves the dependency of type [T].
  ///
  /// Checks overrides first, then local bindings, and finally cascades to [parent].
  /// Throws [StateError] if no provider or override is registered for [T].
  ///
  /// ### Example
  /// ```dart
  /// final db = container.inject<DatabaseService>();
  /// ```
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

  /// Resolves the dependency of type [T], or returns `null` if not registered.
  ///
  /// Checks overrides first, then local bindings, and cascades to [parent].
  ///
  /// ### Example
  /// ```dart
  /// final analytics = container.injectOrNull<AnalyticsService>();
  /// analytics?.logEvent('app_start');
  /// ```
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

  /// Checks whether a dependency of type [T] is registered in this container,
  /// its overrides, or any ancestor [parent] container.
  bool has<T>() =>
      _overrides.containsKey(T) ||
      _bindings.containsKey(T) ||
      (parent?.has<T>() ?? false);

  /// Dumps container registrations, bindings, and active overrides for DevTools inspection.
  ///
  /// Returns a structured map containing binding counts, types, lifecycles, instantiation states,
  /// active override names, and parent status.
  Map<String, dynamic> dumpContainer() {
    final bindingsList = <Map<String, dynamic>>[];
    _bindings.forEach((type, binding) {
      bindingsList.add({
        'type': type.toString(),
        'kind': binding.type.name,
        'isInstantiated': binding.instance != null,
      });
    });

    final overridesList = _overrides.keys.map((k) => k.toString()).toList();

    return {
      'bindingsCount': _bindings.length,
      'bindings': bindingsList,
      'overridesCount': _overrides.length,
      'overrides': overridesList,
      'hasParent': parent != null,
    };
  }

  /// Clears all local bindings and active overrides from this container.
  void reset() {
    _bindings.clear();
    _overrides.clear();
  }
}

/// Global active container used by the framework.
BloomContainer _activeContainer = BloomContainer();

/// Accesses the global active Bloom DI container.
BloomContainer get globalContainer => _activeContainer;

/// Sets the currently active global container (used by [BloomTestScope] for test isolation).
void setActiveContainer(BloomContainer container) {
  _activeContainer = container;
}

/// Resets the global active container to a fresh, empty [BloomContainer] instance.
void resetActiveContainer() {
  _activeContainer.reset();
  _activeContainer = BloomContainer();
}

/// Resolves a dependency of type [T] from the global active Bloom container.
///
/// Throws [StateError] if [T] has not been registered.
///
/// ### Example
/// ```dart
/// final logger = inject<BloomLogger>();
/// ```
T inject<T>() => globalContainer.inject<T>();

/// Resolves an optional dependency of type [T] from the global active Bloom container,
/// or returns `null` if not registered.
///
/// ### Example
/// ```dart
/// final metrics = injectOrNull<MetricsCollector>();
/// ```
T? injectOrNull<T>() => globalContainer.injectOrNull<T>();

/// Registers a transient [factory] on the global active Bloom container.
///
/// A fresh instance of [T] is created each time [inject] is called.
///
/// ### Example
/// ```dart
/// provide<PaymentGateway>(() => StripeGateway());
/// ```
void provide<T>(FactoryFunc<T> factory) => globalContainer.provide<T>(factory);

/// Registers a singleton [factory] on the global active Bloom container.
///
/// The instance is created once and reused across all subsequent resolutions.
/// If [lazy] is `true` (default), instantiation is deferred until first resolution.
///
/// ### Example
/// ```dart
/// provideSingleton<DatabaseClient>(() => DatabaseClient());
/// ```
void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) =>
    globalContainer.provideSingleton<T>(factory, lazy: lazy);

/// Registers an existing instance [value] on the global active Bloom container.
///
/// ### Example
/// ```dart
/// provideValue<ServerConfig>(config);
/// ```
void provideValue<T>(T value) => globalContainer.provideValue<T>(value);
