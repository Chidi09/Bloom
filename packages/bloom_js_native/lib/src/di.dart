// lib/src/di.dart
import 'dart:collection';

/// Factory function callback that instantiates a dependency of type [T].
///
/// Invoked by [BloomContainer.provide] and [BloomContainer.provideSingleton] when resolving dependencies.
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

/// Lightweight, hierarchical Dependency Injection (DI) container for Bloom JS Native applications.
///
/// [BloomContainer] manages service registrations, lifecycle scopes (transient, singleton, value),
/// hierarchical parent-child inheritance, and test overrides without any reflection or Flutter dependencies.
///
/// ### Lifecycles & Registration Kinds
/// - **Transient ([provide])**: The factory is executed on every [inject] call, returning a new instance each time.
/// - **Singleton ([provideSingleton])**: The factory is executed once (either immediately or upon first [inject]
///   when `lazy: true`), and the same instance is returned for all subsequent resolutions in this container.
/// - **Value ([provideValue])**: A pre-existing instance is bound directly to the container.
/// - **Test Overrides ([override], [overrideType])**: High-priority instances that supersede registered factories
///   without unregistering them, easily reverted via [removeOverride].
///
/// ### Hierarchy & Scoping
/// Containers support hierarchical resolution through [parent]. When resolving via [inject] or [injectOrNull],
/// the container first checks its local overrides, then its local bindings, and finally delegates to its [parent]
/// container if not found locally.
///
/// ### Error Handling
/// - [inject] throws a [StateError] if the requested type has not been registered in the container or any ancestor.
/// - [injectOrNull] gracefully returns `null` if the requested type is unregistered.
///
/// ### SSR & Browser Compatibility
/// Safe for both server-side rendering and client-side browser runtimes. On SSR servers, child containers
/// can be created per HTTP request to achieve request-scoped dependency isolation:
/// ```dart
/// final requestContainer = BloomContainer(parent: globalContainer);
/// requestContainer.provideValue<UserSession>(session);
/// ```
///
/// ### Example
/// ```dart
/// final container = BloomContainer();
///
/// // Register dependencies
/// container.provideSingleton<BloomHttpClient>(() => BloomHttpClient());
/// container.provide<AuthService>(() => AuthService(client: container.inject()));
///
/// // Resolve
/// final auth = container.inject<AuthService>();
/// ```
///
/// See also:
/// - [globalContainer], the default ambient container instance.
/// - [inject], the global shortcut for `globalContainer.inject<T>()`.
/// - [provideSingleton], the global shortcut for `globalContainer.provideSingleton<T>()`.
class BloomContainer {
  /// Optional parent container for hierarchical dependency lookup fallback.
  final BloomContainer? parent;
  final Map<Type, _Binding<dynamic>> _bindings =
      HashMap<Type, _Binding<dynamic>>();
  final Map<Type, dynamic> _overrides = HashMap<Type, dynamic>();

  /// Creates a [BloomContainer] with an optional [parent] container.
  ///
  /// When [parent] is provided, unresolved lookups in this container will
  /// recursively delegate to [parent].
  ///
  /// ```dart
  /// final childContainer = BloomContainer(parent: globalContainer);
  /// ```
  BloomContainer({this.parent});

  /// Registers a transient factory for type [T].
  ///
  /// The provided [factory] is invoked on every resolution via [inject] or [injectOrNull],
  /// creating and returning a fresh instance each time. Overwrites any previous registration for [T].
  ///
  /// ```dart
  /// container.provide<UuidGenerator>(() => UuidGenerator());
  /// ```
  void provide<T>(FactoryFunc<T> factory) {
    _bindings[T] = _Binding<T>.transient(factory);
  }

  /// Registers a singleton factory for type [T].
  ///
  /// When [lazy] is `true` (the default), [factory] is evaluated on the first [inject] call
  /// and the resulting instance is cached for all future resolutions. When [lazy] is `false`,
  /// [factory] is executed immediately upon registration.
  ///
  /// ```dart
  /// container.provideSingleton<DatabaseService>(() => DatabaseService(), lazy: true);
  /// ```
  void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) {
    _bindings[T] = _Binding<T>.singleton(factory, lazy: lazy);
  }

  /// Registers an existing instance [value] for type [T].
  ///
  /// Directly binds [value] without evaluating a factory. All subsequent resolutions
  /// for [T] will return this exact instance.
  ///
  /// ```dart
  /// container.provideValue<AppConfig>(AppConfig(env: 'production'));
  /// ```
  void provideValue<T>(T value) {
    _bindings[T] = _Binding<T>.value(value);
  }

  /// Registers a high-precedence test override for generic type [T].
  ///
  /// Overrides take priority over registered transient, singleton, and value bindings,
  /// as well as parent container bindings. Useful for injecting mock objects during unit testing.
  ///
  /// ```dart
  /// container.override<AuthService>(MockAuthService());
  /// ```
  void override<T>(T instance) {
    _overrides[T] = instance;
  }

  /// Registers a high-precedence test override for an explicit runtime [type].
  ///
  /// Equivalent to [override], but accepts a dynamic [Type] token instead of a generic parameter.
  ///
  /// ```dart
  /// container.overrideType(AuthService, MockAuthService());
  /// ```
  void overrideType(Type type, dynamic instance) {
    _overrides[type] = instance;
  }

  /// Removes a test override registered for generic type [T] or explicit [type].
  ///
  /// Restores normal resolution behavior from underlying bindings or parent containers.
  ///
  /// ```dart
  /// container.removeOverride<AuthService>();
  /// ```
  void removeOverride<T>([Type? type]) {
    _overrides.remove(type ?? T);
  }

  /// Resolves a dependency of type [T].
  ///
  /// Lookups proceed in the following order:
  /// 1. Local overrides registered via [override] or [overrideType].
  /// 2. Local bindings registered via [provide], [provideSingleton], or [provideValue].
  /// 3. Recursive lookup in [parent], if present.
  ///
  /// Throws a [StateError] if no provider is registered for [T] in this container or its ancestors.
  ///
  /// ```dart
  /// final client = container.inject<BloomHttpClient>();
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

  /// Resolves a dependency of type [T], returning `null` if unregistered.
  ///
  /// Performs the same resolution chain as [inject], but returns `null` instead
  /// of throwing a [StateError] when no binding or override is found.
  ///
  /// ```dart
  /// final analytics = container.injectOrNull<AnalyticsService>();
  /// analytics?.trackEvent('app_start');
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

  /// Checks whether a provider or override for type [T] is registered in this container or its ancestors.
  ///
  /// Returns `true` if type [T] can be resolved without throwing; otherwise `false`.
  ///
  /// ```dart
  /// if (container.has<NotificationService>()) {
  ///   container.inject<NotificationService>().notify('Ready');
  /// }
  /// ```
  bool has<T>() =>
      _overrides.containsKey(T) ||
      _bindings.containsKey(T) ||
      (parent?.has<T>() ?? false);

  /// Dumps diagnostic metadata about all registered bindings and overrides in this container.
  ///
  /// Returns a map containing counts, registered types, binding kinds (`transient`, `singleton`, `value`),
  /// instantiation status for singletons, active overrides, and whether a parent container exists.
  ///
  /// ```dart
  /// final diagnostics = container.dumpContainer();
  /// print('Container state: $diagnostics');
  /// ```
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

  /// Clears all local bindings and overrides from this container.
  ///
  /// Does not affect [parent]. Useful for resetting state during test teardown.
  ///
  /// ```dart
  /// container.reset();
  /// ```
  void reset() {
    _bindings.clear();
    _overrides.clear();
  }
}

/// Global active container used by the framework.
BloomContainer _activeContainer = BloomContainer();

/// Returns the ambient global [BloomContainer] instance.
///
/// Used by top-level dependency injection functions ([inject], [provide], [provideSingleton], [provideValue]).
///
/// ```dart
/// final container = globalContainer;
/// ```
BloomContainer get globalContainer => _activeContainer;

/// Replaces the ambient global container with [container].
///
/// Useful for testing to isolate registrations between test suites or for setting up request-scoped containers.
///
/// ```dart
/// final testContainer = BloomContainer();
/// setActiveContainer(testContainer);
/// ```
void setActiveContainer(BloomContainer container) {
  _activeContainer = container;
}

/// Resets the ambient global container to a fresh, empty [BloomContainer].
///
/// Clears existing bindings and instantiates a new container. Recommended in test `tearDown()` hooks.
///
/// ```dart
/// resetActiveContainer();
/// ```
void resetActiveContainer() {
  _activeContainer.reset();
  _activeContainer = BloomContainer();
}

/// Resolves a dependency of type [T] from the [globalContainer].
///
/// Throws a [StateError] if no provider or override for [T] is registered.
///
/// ```dart
/// final client = inject<BloomHttpClient>();
/// ```
T inject<T>() => globalContainer.inject<T>();

/// Resolves a dependency of type [T] from the [globalContainer], or returns `null` if unregistered.
///
/// ```dart
/// final maybeService = injectOrNull<AnalyticsService>();
/// ```
T? injectOrNull<T>() => globalContainer.injectOrNull<T>();

/// Registers a transient factory on the [globalContainer].
///
/// A new instance is constructed via [factory] on every resolution.
///
/// ```dart
/// provide<TaskValidator>(() => TaskValidator());
/// ```
void provide<T>(FactoryFunc<T> factory) => globalContainer.provide<T>(factory);

/// Registers a singleton factory on the [globalContainer].
///
/// When [lazy] is `true`, [factory] is invoked on the first call to [inject]; when `false`,
/// it is evaluated immediately. The returned instance is reused for all subsequent calls.
///
/// ```dart
/// provideSingleton<AuthStore>(() => AuthStore());
/// ```
void provideSingleton<T>(FactoryFunc<T> factory, {bool lazy = true}) =>
    globalContainer.provideSingleton<T>(factory, lazy: lazy);

/// Registers an existing instance [value] on the [globalContainer].
///
/// ```dart
/// provideValue<String>('https://api.example.com');
/// ```
void provideValue<T>(T value) => globalContainer.provideValue<T>(value);
