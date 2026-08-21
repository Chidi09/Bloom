# Bloom JS Native M9 — Advanced Data, Nested Routing & Concurrent Transitions Design Specification

## 1. Architectural Scope & Goals

This specification defines **Milestone 9 (M9)** for `packages/bloom_js_native`. Following the core UI/AST and hydration foundations built in M7 and M8, M9 delivers full parity with Bloom's full-stack framework across three critical pillars:
1. **SWR Data Layer (`BloomQuery` & `BloomMutation`)**: Stale-while-revalidate caching, in-flight request deduplication, cache tag invalidation, and seamless integration with `Suspense` and `Live`.
2. **Advanced Routing (`BloomRouteGuard` & Nested `BloomRoute.shell`)**: Navigation guards with redirection contracts and persistent shell layouts for dashboards and tab views.
3. **Concurrent Reactivity & Transitions (`startTransition` & `isPending`)**: Non-blocking deferred reactivity to prioritize urgent user inputs over heavy subtree rendering.

---

## 2. Subsystem Architecture

### 2.1 Pure-Dart Stale-While-Revalidate Data Layer (`lib/src/data.dart`)

**Files:** `lib/src/data.dart`, exported via `lib/bloom_js_native.dart`

```dart
/// Execution status of a [BloomQuery].
enum QueryStatus { idle, loading, success, error }

/// Declarative cached query with SWR revalidation.
class BloomQuery<T> {
  final List<dynamic> key;
  final Future<T> Function() fetch;
  final Duration staleTime;
  final Duration cacheTime;

  ReadonlySignal<T?> get data;
  ReadonlySignal<QueryStatus> get status;
  ReadonlySignal<Object?> get error;
  ReadonlySignal<bool> get isFetching;
  ReadonlySignal<bool> get isStale;

  Future<T?> refetch();
  void setData(T newData);
  void dispose();
}

/// Global query cache manager for bloom_js_native.
class BloomData {
  static void invalidateQueries(List<dynamic> keyPrefix);
  static void setQueryData<T>(List<dynamic> key, T Function(T? oldData) updater);
  static T? getQueryData<T>(List<dynamic> key);
  static void clear();
}
```

- **Suspense Integration**: `Suspense(resource: query.fetch, builder: (data) => ...)` or direct signal binding `Live(() => query.isLoading ? LoadingSpinner() : View(query.data.value!))`.
- **Deduplication**: Simultaneous calls to `fetch` with the same key share a single `Future<T>`.

---

### 2.2 Route Guards & Persistent Shell Layouts (`lib/src/router.dart`)

**Files:** `lib/src/router.dart`, `lib/src/router_browser.dart`

```dart
/// Guard execution result.
class GuardResult {
  final bool isAllowed;
  final String? redirectPath;

  const GuardResult._({required this.isAllowed, this.redirectPath});
  factory GuardResult.allow() => const GuardResult._(isAllowed: true);
  factory GuardResult.redirect(String path) => GuardResult._(isAllowed: false, redirectPath: path);
}

/// Abstract contract for client navigation guards.
abstract class BloomRouteGuard {
  const BloomRouteGuard();
  FutureOr<GuardResult> canActivate(String location, Map<String, String> params);
}

/// Extended route with guards and nested sub-routes.
class BloomRoute {
  final String path;
  final BloomNode Function(Map<String, String> params)? builder;
  final BloomNode Function(BloomNode child, Map<String, String> params)? layout;
  final List<BloomRouteGuard> guards;
  final List<BloomRoute> children;

  const BloomRoute(
    this.path, {
    this.builder,
    this.layout,
    this.guards = const [],
    this.children = const [],
  });

  /// Factory for persistent shell layouts (sidebars, navbars).
  factory BloomRoute.shell({
    required BloomNode Function(BloomNode child, Map<String, String> params) layout,
    required List<BloomRoute> routes,
    List<BloomRouteGuard> guards = const [],
  }) { ... }
}
```

- **Guard Execution**: When `navigate(path)` or `popstate` occurs, `BloomRouterController` runs all matched guards in sequence. If a guard returns `GuardResult.redirect(path)`, navigation immediately halts and re-targets the redirect path.
- **Layout Shells**: If a matched route has a parent shell or `layout`, the inner child descriptor is wrapped within the layout function without re-mounting the outer layout DOM structure.

---

### 2.3 Concurrent Transitions (`lib/src/transition.dart`)

**Files:** `lib/src/transition.dart`, exported via `lib/bloom_js_native.dart`

```dart
/// Global transition state signal indicating whether a background update is in-flight.
ReadonlySignal<bool> get isTransitionPending;

/// Executes non-urgent signal updates inside a deferred transition frame.
void startTransition(void Function() update);
```

- Urgent updates (e.g. text input signals) execute immediately.
- Background / non-urgent updates inside `startTransition` batch signal changes into a `microtask` or `requestAnimationFrame`, toggling `isTransitionPending` while async work settles.

---

## 3. Testing & Quality Strategy

1. **VM Unit Tests (`dart test`)**:
   - `test/data_test.dart`: Cache lookup, SWR invalidation cascade, request deduplication, mutation optimistics.
   - `test/router_guards_test.dart`: Guard allow/deny/redirect paths, parameter forwarding.
   - `test/router_shell_test.dart`: Nested layout resolution and parameter inheritance.
   - `test/transition_test.dart`: `startTransition` and `isTransitionPending` signal state.
2. **Monorepo Quality Gate**:
   - `dart analyze packages/bloom_js_native` with **0 errors and 0 warnings**.
   - `cd packages/bloom_framework && flutter test` to ensure monorepo alignment.
