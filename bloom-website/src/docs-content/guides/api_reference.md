# 39. Bloom v1.0 Public API Reference

Comprehensive symbol-level index of all classes, functions, and interfaces exported by `package:bloom_framework/bloom.dart`.

---

## 🏛️ Core & Boot (`src/core/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `Bloom.boot` | `Future<void> Function({BloomBootstrapper? bootstrapper, String? flavor})` | Boots framework runtime, DI, logging, env, cache GC, and OTA. |
| `Bloom.reset` | `void Function()` | Resets all runtime memory, containers, and services between tests. |
| `Bloom.config` | `BloomConfig get` | Parsed configuration from `bloom.yaml`. |
| `Bloom.isBooted` | `bool get` | Boolean flag indicating whether `Bloom.boot()` has completed. |
| `Bloom.activeFlavor` | `String? get` | Active build flavor name. |
| `BloomBootstrapper` | `abstract class` | Contract for startup hooks (`onBoot(BloomContainer)`). |
| `BloomEnv` | `class` | Static accessors for typed environment variables (`get`, `getInt`, `getBool`). |
| `logger` | `BloomLogger` | Global structured logging utility. |

---

## 📦 Dependency Injection (`src/di/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `inject<T>()` | `T Function<T>()` | Resolves a dependency from the active container (throws if missing). |
| `injectOrNull<T>()` | `T? Function<T>()` | Resolves an optional dependency (returns null if missing). |
| `BloomContainer` | `class` | IoC container (`provide`, `provideSingleton`, `provideValue`, `dumpContainer`). |
| `BloomTestScope` | `class` | Isolated test container scope that swaps the active container. |
| `BloomTestOverride<T>`| `class` | Encapsulates a mock instance for `BloomTestScope`. |

---

## ⚡ Reactivity & State (`src/state/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `signal<T>()` | `Signal<T> Function<T>(T initial, {String? debugLabel})` | Creates a mutable reactive signal. |
| `computed<T>()` | `Computed<T> Function<T>(T Function() compute, {String? debugLabel})` | Creates a derived memoized signal. |
| `effect()` | `void Function() Function(void Function() effect)` | Subscribes to signals and triggers side effects. |
| `batch()` | `void Function(void Function() action)` | Batches multiple signal updates into one notification cycle. |
| `Watch` | `Widget` | Widget that rebuilds only when read signals change. |
| `SignalBuilder<T>` | `Widget` | Explicit widget binding to a specific `Signal<T>`. |
| `BloomController` | `abstract class` | Base class for state controllers (`onInit`, `onDispose`, `addEffect`). |

---

## 🧭 Routing (`src/router/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `BloomRouter.go` | `void Function(String location, {Object? extra})` | Navigates to target URL. |
| `BloomRouter.push` | `void Function(String location, {Object? extra})` | Pushes route onto navigation stack. |
| `BloomRouter.pop` | `void Function()` | Pops active route. |
| `BloomRouter.replace` | `void Function(String location, {Object? extra})` | Replaces active route. |
| `BloomGuard` | `abstract class` | Intercepts navigation matches (`canActivate`). |
| `BloomAuthGuard` | `class` | Built-in guard redirecting unauthenticated users to a login path. |

---

## 💾 Data & Offline (`src/data/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `BloomData.query<T>()` | `BloomQuery<T> Function<T>(...)` | Creates or retrieves a cached asynchronous query. |
| `BloomData.mutation<T,P>()`| `BloomMutation<T,P> Function<T,P>(...)` | Creates an asynchronous mutation with optimistic rollback. |
| `BloomData.invalidateQueries`| `void Function(List<dynamic> keyPrefix)` | Invalidates queries matching key prefix. |
| `BloomHttpClient` | `class` | Typed HTTP client (`get`, `post`, `put`, `patch`, `delete`). |
| `BloomRepository` | `abstract class` | Base class for repository services. |
| `BloomCrudRepository<T,ID>`| `abstract class` | Standard CRUD contract (`findAll`, `findById`, `create`, `update`, `delete`). |
| `BloomAuth<U>` | `class` | Reactive authentication manager (`setSession`, `restoreSession`, `logout`). |
| `BloomSecureStorage` | `class` | Hardware-backed encrypted storage. |
| `OfflineMutationQueue` | `class` | Persistent offline action replay queue. |

---

## 🚀 Native, OTA & Adapters (`src/native/`, `src/deployment/`, `src/adapters/`)

| Symbol | Signature / Type | Description |
| :--- | :--- | :--- |
| `BloomPermissions` | `class` | Cross-platform permission manager (`check`, `request`, `openAppSettings`). |
| `BloomNotifications` | `class` | Local push notification dispatcher. |
| `BloomCamera` | `class` | Camera capture controller. |
| `BloomDeepLinks` | `class` | Deep link intent listener and cold-start queue. |
| `BloomOTA` | `class` | Shorebird Over-The-Air update controller (`checkForUpdate`, `downloadUpdate`). |
| `BloomSupabaseAuthAdapter` | `class` | Official Supabase authentication adapter. |
| `BloomSupabaseTableRepository` | `class` | Official Supabase CRUD table repository. |
| `BloomServerpodClient` | `class` | Official Serverpod client and stream signal binder. |
| `BloomServerpodRepository` | `class` | Official Serverpod delegate repository. |
