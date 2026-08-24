// lib/src/di/scope.dart
import 'container.dart';

/// Represents a typed test override instance to be injected into a [BloomTestScope].
///
/// Pairs a runtime [type] with a mock, stub, or fake [instance] to supersede production
/// dependencies during test runs.
///
/// ### Example
/// ```dart
/// final override = BloomTestOverride<DatabaseService>(MockDatabaseService());
/// ```
class BloomTestOverride<T> {
  /// The dependency runtime type to override.
  final Type type;

  /// The mock or stub instance to resolve for [type].
  final T instance;

  /// Creates a test override for type [T] using the provided [instance].
  BloomTestOverride(this.instance) : type = T;
}

/// A scoped DI harness for running unit and integration tests with isolated overrides.
///
/// When instantiated, [BloomTestScope] creates a child [BloomContainer] wrapping the
/// active [globalContainer] (or a custom [parent]), installs any supplied [overrides],
/// and sets the child container as the active global container via [setActiveContainer].
///
/// Calling [dispose] resets the child container and restores the previous active container,
/// preventing state leakage between test cases.
///
/// ### Example
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:bloom_server/bloom_core.dart';
///
/// void main() {
///   late BloomTestScope scope;
///   late MockAuthService mockAuth;
///
///   setUp(() {
///     mockAuth = MockAuthService();
///     scope = BloomTestScope(overrides: [
///       BloomTestOverride<AuthService>(mockAuth),
///     ]);
///   });
///
///   tearDown(() {
///     scope.dispose();
///   });
///
///   test('resolves mocked auth service', () {
///     final auth = inject<AuthService>();
///     expect(auth, same(mockAuth));
///   });
/// }
/// ```
class BloomTestScope {
  /// The isolated container managed by this test scope.
  final BloomContainer container;
  final BloomContainer _previousContainer;

  /// Creates a [BloomTestScope] with optional [parent] container and initial [overrides].
  ///
  /// Automatically calls [setActiveContainer] with this scope's child container.
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

  /// Injects an override for type [T] with [mockInstance] into this isolated test scope.
  ///
  /// ### Example
  /// ```dart
  /// scope.override<PaymentGateway>(FakePaymentGateway());
  /// ```
  void override<T>(T mockInstance) {
    container.override<T>(mockInstance);
  }

  /// Resolves dependency of type [T] within this test scope.
  ///
  /// Throws [StateError] if [T] cannot be resolved from this scope or its parent.
  T inject<T>() => container.inject<T>();

  /// Resolves optional dependency of type [T] within this test scope, or returns `null`.
  T? injectOrNull<T>() => container.injectOrNull<T>();

  /// Disposes this test scope, cleans up local overrides, and restores the previous active container.
  ///
  /// Always call this in your test suite's `tearDown()` block.
  void dispose() {
    container.reset();
    setActiveContainer(_previousContainer);
  }
}

