# 45. Platform Capabilities, Production Features & Current Gaps

To maintain complete architectural integrity and transparency for engineers evaluating Bloom v1.0, this document explicitly details what features are **fully production-ready** versus what capabilities currently operate as **Dart facades, protocol wrappers, or staged mocks**.

---

## 🟢 1. Fully Production-Ready Subsystems

The following framework modules are completely implemented with real production dependencies, rigorous unit/widget test suites, and zero stubs:

| Subsystem | Production Implementation Details |
| :--- | :--- |
| **Reactivity & State** | Built directly on `signals_flutter: ^5.5.1`. Zero boilerplate fine-grained signals, computeds, effects, and `Watch` widgets. |
| **Dependency Injection** | Type-safe IoC container with singleton/factory/value lifecycles, child container scoping, and `BloomTestScope` isolation. |
| **Filesystem Routing** | AST route scanner compiling filesystem directory trees into fully typed `GoRouter` tables with parameter capture and `BloomAuthGuard`. |
| **Bloom Data Query Cache** | In-memory query caching, key array normalization, prefix invalidations, TTL background garbage collection, and optimistic mutation rollbacks. |
| **Secure Key-Value Storage** | Built directly on `flutter_secure_storage: ^9.2.4` for hardware-backed iOS Keychain and Android Keystore encryption. |
| **Local Push Notifications** | Built on `flutter_local_notifications: ^17.2.4` with Android notification channels, vibration triggers, and permission handling. |
| **Runtime Permissions** | Powered by `permission_handler: ^11.4.0` with cross-platform status normalization. |
| **Native Prebuild Engine** | Deterministic XML/AST parser synchronizing permissions, SDK versions, plist strings, and `.well-known` domain verification files. |
| **Shorebird OTA Updater** | Built directly on `shorebird_code_push: ^2.0.7` wrapping `ShorebirdUpdater` for real patch checking, engine-level staging, and patch metadata. |
| **Supabase Full-Stack Adapter** | Built directly on `supabase_flutter: ^2.17.1` with session persistence, real token refresh, and CRUD table repository integration. |
| **Standardized Testing Harness** | `bloom_testing.dart` with `pumpBloomApp`, active container override scoping, and `BloomMock` call tracking. |

---

## 🟡 2. Capabilities Staged as Dart Facades / Protocols (Current Version Gaps)

Developers should be aware of the following nuances and planned engine extensions in the current v1.0 release:

### 1. `BloomCamera` & `BloomBackground` MethodChannels
* **Current Behavior:** `BloomCamera` utilizes `image_picker` when available on standard mobile platforms and falls back to invoking `MethodChannel('bloom/camera')`. `BloomBackground` wraps `MethodChannel('bloom/background')`.
* **Important Note:** In vanilla Flutter sample apps where `MainActivity.kt` and `AppDelegate.swift` have not declared custom native method handlers for `'bloom/camera'` or `'bloom/background'`, invoking these custom channels without `image_picker` installed will throw a `MissingPluginException`.

### 2. Bloom Go Remote Dart JIT Execution
* **Current Behavior:** **Bloom Go** (`apps/bloom_go`) pairs wirelessly with `bloom dev` via camera QR scanning (`mobile_scanner`), broadcasts UDP beacons on port `5354`, synchronizes live project manifests (`/manifest.json`), and renders an in-app `BloomDevOverlay` cache/container inspector.
* **Important Note:** Bloom Go does not currently execute arbitrary remote Dart JIT bytecode over WebSockets in the style of Expo Go; it acts as a project manifest visualizer, remote inspector, and device pairing hub. Direct remote bytecode compilation into the shell app is targeted for Bloom v2.0.

### 3. Serverpod Adapter Socket Loop
* **Current Behavior:** `BloomServerpodClient` manages connection status flags, auth tokens, and provides `signalFromStream<T>()` to bind reactive Signals to real-time streams with explicit `dispose()` cleanup. `BloomServerpodRepository` delegates CRUD operations to Serverpod endpoint methods.
* **Important Note:** `BloomServerpodClient` acts as a stream binder and delegate repository bridge; it does not implement a raw TCP/WebSocket socket loop internally, relying instead on your project's generated Serverpod client classes.
