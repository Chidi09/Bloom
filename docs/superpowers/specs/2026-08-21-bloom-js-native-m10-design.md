# Bloom JS Native M10 — Full-Stack Cross-Platform Parity Design Specification

## 1. Architectural Scope & Goals

This specification defines **Milestone 10 (M10)** for `packages/bloom_js_native`. M10 achieves complete full-stack parity with `bloom_framework` by porting all battle-tested, pure-Dart infrastructure layers with zero Flutter SDK dependencies:

1. **Declarative Mutations & Optimistic Rollback (`BloomMutation<T, P>`)**:
   - Automated cache snapshotting, optimistic UI rendering, automatic rollback on error, and automatic query cache invalidation.
2. **Isomorphic HTTP Client (`BloomHttpClient`)**:
   - Environment base URL resolution, JSON codecs, Bearer auth token injection, and request/response interceptors.
3. **Environment Parsing & Schema Validation (`BloomEnv` & `BloomEnvironmentSchema`)**:
   - `.env` string parsing, `--dart-define` seeding, and `BloomEnv.validate(schema)` with fast-fail typed validators (`requireString`, `requireInt`, `requireUri`, etc.).
4. **Dependency Injection Container (`BloomContainer`)**:
   - `inject<T>()`, `provide<T>()`, `provideSingleton<T>()`, `provideValue<T>()`, and `override<T>()` with hierarchical lookup.
5. **Dynamic Feature Flags (`BloomFeatureFlags`)**:
   - Reactive signal-backed feature flags (`watch(flag)`, `isEnabled(flag)`, `setOverride(flag, val)`).
6. **State Controllers (`BloomController`)**:
   - Lifecycle controller base class with `onInit()`, `onDispose()`, `addEffect(cb)`, and `autoDispose(cleanup)`.

---

## 2. Subsystem Architecture

### 2.1 Declarative Mutations (`lib/src/mutation.dart`)

```dart
enum MutationStatus { idle, pending, success, error }

class BloomMutation<T, P> {
  final Future<T> Function(P params) mutateFn;
  final List<dynamic>? optimisticKey;
  final T? Function(P params, T? oldData)? optimisticData;
  final List<List<dynamic>> invalidateKeys;

  ReadonlySignal<T?> get data;
  ReadonlySignal<MutationStatus> get status;
  ReadonlySignal<Object?> get error;

  Future<T?> mutate(P params);
  Future<T> mutateAsync(P params);
  void reset();
}
```

### 2.2 Isomorphic HTTP Client (`lib/src/http.dart`)

```dart
class BloomHttpClient {
  final String? baseUrl;
  final Duration timeout;
  String? authToken;
  String? Function()? authTokenProvider;

  Future<T> get<T>(String path, {Map<String, String>? headers, Map<String, dynamic>? queryParameters});
  Future<T> post<T>(String path, {dynamic body, Map<String, String>? headers, Map<String, dynamic>? queryParameters});
  Future<T> put<T>(String path, {dynamic body, Map<String, String>? headers, Map<String, dynamic>? queryParameters});
  Future<T> patch<T>(String path, {dynamic body, Map<String, String>? headers, Map<String, dynamic>? queryParameters});
  Future<T> delete<T>(String path, {dynamic body, Map<String, String>? headers, Map<String, dynamic>? queryParameters});
  void close();
}
```

### 2.3 Environment & Schema Validation (`lib/src/env.dart`)

```dart
abstract class BloomEnvironmentSchema {
  String requireString(String key, {String? description});
  int requireInt(String key, {String? description});
  bool requireBool(String key, {String? description});
  Uri requireUri(String key, {String? description});
  void validate();
}

class BloomEnv {
  static void loadContent(String content, {bool overwrite = true});
  static void loadMap(Map<String, String> map, {bool overwrite = true});
  static T validate<T extends BloomEnvironmentSchema>(T schema);
  static String get(String key, {String? defaultValue});
  static String? getOrNull(String key);
}
```

### 2.4 Dependency Injection (`lib/src/di.dart`)

```dart
class BloomContainer {
  void provide<T>(T Function() factory);
  void provideSingleton<T>(T Function() factory, {bool lazy = true});
  void provideValue<T>(T value);
  T inject<T>();
  T? injectOrNull<T>();
}

T inject<T>() => globalContainer.inject<T>();
void provide<T>(T Function() factory) => globalContainer.provide<T>(factory);
void provideSingleton<T>(T Function() factory, {bool lazy = true}) => globalContainer.provideSingleton<T>(factory, lazy: lazy);
```

### 2.5 Feature Flags (`lib/src/features.dart`)

```dart
class BloomFeatureFlags {
  bool isEnabled(String flagName, {bool defaultValue = false});
  ReadonlySignal<bool> watch(String flagName, {bool defaultValue = false});
  void setOverride(String flagName, bool value);
  void register(String flagName, {bool defaultValue = false});
  void registerAll(Map<String, dynamic> flags);
}
```

### 2.6 State Controllers (`lib/src/controller.dart`)

```dart
abstract class BloomController {
  bool get isDisposed;
  void onInit();
  void addEffect(void Function() effectCb, {String? debugLabel});
  void autoDispose(void Function() cleanup);
  void onDispose();
}
```

---

## 3. Monorepo Quality Gate

- Zero Flutter dependencies across all 6 new pure-Dart modules.
- `dart analyze packages/bloom_js_native` passes with **0 errors and 0 warnings**.
- Full test suite passes across VM and JS targets.
