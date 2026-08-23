// lib/src/controller.dart
import 'package:signals/signals.dart';

/// Base class for stateful controllers and view-models in Bloom JS Native applications.
///
/// [BloomController] encapsulates business logic, reactive signals, and lifecycle management
/// without any dependency on the Flutter SDK. It provides automatic cleanup tracking for
/// signal [effect] callbacks via [addEffect] and arbitrary teardown logic via [autoDispose].
///
/// ### Lifecycle & Dependency Injection
/// - **Initialization**: Subclasses override [onInit] to set up event listeners, initial fetches,
///   or reactive subscriptions. [onInit] is called synchronously in the constructor.
/// - **Disposal**: When the controlling component or container is torn down, call [onDispose].
///   This cancels all effect subscriptions registered with [addEffect] and executes all
///   cleanup callbacks registered with [autoDispose]. Disposal is idempotent and swallows
///   exceptions from individual callbacks to guarantee all disposers run.
/// - **DI Integration**: Controllers are typically registered in the [BloomContainer] as
///   transients (per-view) or singletons (application-wide):
///   ```dart
///   provideSingleton(() => AuthController());
///   provide(() => UserProfileController(inject()));
///   ```
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Subscribed effects and reactive bindings execute on signal mutations.
///   Controllers should be explicitly disposed when components unmount or routers transition.
/// - **SSR (`renderToHtml`)**: Safe to instantiate during SSR to compute initial state descriptors.
///   Avoid creating persistent timers or unclosed stream subscriptions during SSR.
///
/// ### Example
/// ```dart
/// class CounterController extends BloomController {
///   final count = signal(0);
///   late final ReadonlySignal<bool> isEven;
///
///   @override
///   void onInit() {
///     super.onInit();
///     isEven = computed(() => count.value.isEven);
///
///     // Automatically cleaned up on onDispose()
///     addEffect(() {
///       // Triggers whenever count.value changes
///     });
///   }
///
///   void increment() => count.value++;
///   void decrement() => count.value--;
/// }
/// ```
///
/// See also:
/// - [BloomContainer], the dependency injection container used to register and resolve controllers.
abstract class BloomController {
  final List<void Function()> _disposers = [];
  bool _isDisposed = false;

  /// Whether this controller has been disposed via [onDispose].
  ///
  /// When `true`, subsequent calls to [addEffect] or [autoDispose] are ignored (no-ops).
  bool get isDisposed => _isDisposed;

  /// Creates a [BloomController] and immediately invokes [onInit].
  ///
  /// Subclasses should place asynchronous setup or signal subscriptions inside [onInit].
  BloomController() {
    onInit();
  }

  /// Called immediately during controller instantiation.
  ///
  /// Override this lifecycle method to initialize signals, compute derived state,
  /// register effects via [addEffect], or register resource teardowns via [autoDispose].
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   super.onInit();
  ///   addEffect(() {
  ///     print('User updated: ${userSignal.value?.name}');
  ///   });
  /// }
  /// ```
  void onInit() {}

  /// Registers a reactive [effect] that is automatically disposed when this controller is disposed.
  ///
  /// The provided [effectCb] is invoked immediately and re-runs whenever any reactive signal
  /// read inside the callback emits a new value. If the controller is already disposed,
  /// this method is a no-op.
  ///
  /// [debugLabel] optionally names the effect for debugging in devtools.
  ///
  /// ```dart
  /// addEffect(() {
  ///   if (isLoggedIn.value) {
  ///     fetchDashboardData();
  ///   }
  /// }, debugLabel: 'auth-dashboard-trigger');
  /// ```
  void addEffect(void Function() effectCb, {String? debugLabel}) {
    if (_isDisposed) return;
    final dispose =
        effect(effectCb, debugLabel: debugLabel ?? '$runtimeType.effect');
    _disposers.add(dispose);
  }

  /// Registers a custom cleanup callback to execute when [onDispose] is called.
  ///
  /// Use this to close stream subscriptions, cancel timers, abort HTTP requests,
  /// or release native resources. If the controller is already disposed, this is a no-op.
  ///
  /// ```dart
  /// final timer = Timer.periodic(Duration(seconds: 1), (_) => tick());
  /// autoDispose(() => timer.cancel());
  /// ```
  void autoDispose(void Function() cleanup) {
    if (_isDisposed) return;
    _disposers.add(cleanup);
  }

  /// Disposes all registered effects, cleanup callbacks, and resources.
  ///
  /// Iterates through all callbacks registered via [addEffect] and [autoDispose],
  /// executing each in order. Disposal is idempotent; subsequent invocations have no effect.
  /// Any exceptions thrown by individual disposers are caught and swallowed to guarantee
  /// all remaining cleanup callbacks are executed.
  ///
  /// ```dart
  /// controller.onDispose();
  /// print(controller.isDisposed); // true
  /// ```
  void onDispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final dispose in _disposers) {
      try {
        dispose();
      } catch (_) {
        // Best-effort cleanup: swallow errors during disposal
      }
    }
    _disposers.clear();
  }
}
