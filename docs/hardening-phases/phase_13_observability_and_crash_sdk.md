# Phase 13: Error Observability, Crash SDK & Telemetry

> **Objective:** Deliver an integrated real-time crash capture and telemetry pipeline bridging Flutter framework errors, Dart zone exceptions, native Android/iOS crashes, breadcrumbs, source maps, and symbolication.

---

## 🏗️ Observability Architecture

```text
               Bloom Application Runtime
                          │
  ┌───────────────────────┼───────────────────────┐
  ▼                       ▼                       ▼
Flutter Errors       Zone / Async Errors     Native Crashes
(FlutterError.onError) (PlatformDispatcher)   (JVM / Mach-O Signal)
  │                       │                       │
  └───────────────────────┼───────────────────────┘
                          ▼
            Bloom Crash Reporting Pipeline
                          │
        ┌─────────────────┴─────────────────┐
        ▼                                   ▼
Release Fingerprinting              Breadcrumb Timeline
(App, Build, Patch ID, Channel)    (Nav, Network, State)
        │                                   │
        └─────────────────┬─────────────────┘
                          ▼
             Symbolication & Crash Grouping
          (dSYM / ProGuard / Dart Source Maps)
```

---

## 🚨 1. Automated Error Capture

Bloom automatically wraps Flutter and Dart asynchronous error boundaries during `Bloom.boot()`:

```dart
// lib/main.dart
void main() async {
  await Bloom.boot(
    bootstrapper: AppBootstrapper(),
    observability: BloomObservabilityConfig(
      enabled: true,
      sampleRate: 1.0,
      autoCaptureFlutterErrors: true,
      autoCaptureZoneErrors: true,
      autoCaptureNativeCrashes: true,
    ),
  );

  runApp(const MyApp());
}
```

---

## 🍞 2. Contextual Breadcrumb Recording

Bloom records an in-memory chronological timeline of user actions, route transitions, and HTTP requests leading up to a crash:

```dart
// Automatic breadcrumb capture:
// 10:31:01 ➔ [NAV] Route pushed: /products/42
// 10:31:02 ➔ [NET] GET https://api.bloom.dev/products/42 (200 OK - 84ms)
// 10:31:04 ➔ [STATE] CartController.addItem(id: '42')
// 10:31:05 ➔ [UI] Tap: Button[id="checkout_button"]
// 10:31:06 ➔ [CRASH] StateError: Null check operator used on a null value
```

### Adding Custom Breadcrumbs
```dart
Bloom.addBreadcrumb(
  category: 'auth',
  message: 'User initiated biometric login',
  level: BloomBreadcrumbLevel.info,
  data: {'biometricType': 'faceId'},
);
```

---

## 🏷️ 3. Structured Error Context (`Bloom.captureException`)

Manually capture handled exceptions with structured domain context:

```dart
try {
  await paymentGateway.charge(order);
} catch (e, stackTrace) {
  Bloom.captureException(
    e,
    stackTrace: stackTrace,
    context: {
      'order_id': order.id,
      'amount': order.total,
      'payment_method': 'apple_pay',
      'user_id': auth.currentUser.value?.id,
    },
    fingerprint: ['payment_gateway', order.paymentMethod],
  );
}
```

---

## 🔬 4. Release Fingerprinting & Metadata

Every error report automatically attaches comprehensive deployment telemetry:

```json
{
  "eventId": "err_01HZX8N6V1",
  "timestamp": "2026-08-14T11:45:00Z",
  "app": {
    "name": "bloom_shop",
    "version": "1.0.0",
    "buildNumber": "42"
  },
  "runtime": {
    "bloomVersion": "1.0.0",
    "flutterVersion": "3.27.0",
    "dartVersion": "3.6.0",
    "runtimeFingerprint": "e3b0c44298fc...",
    "activePatchId": "patch_102",
    "channel": "production"
  },
  "device": {
    "model": "iPhone 15 Pro",
    "os": "iOS 17.5.1",
    "memoryFreeMb": 1280
  }
}
```

---

## 🗺️ 5. Symbolication Pipeline (dSYM, ProGuard & Source Maps)

During production builds (`bloom build` or `bloom deploy`), the CLI automatically exports and packages symbol files:
* **Android:** ProGuard / R8 mapping files (`mapping.txt`).
* **iOS / macOS:** Native Mach-O dSYM bundles (`Runner.app.dSYM`).
* **Web:** Dart-to-JavaScript source maps (`main.dart.js.map`).

---

## 🧪 Verification & Acceptance Criteria

1. Unhandled Dart exceptions in asynchronous futures and Flutter widget render trees are captured with stack traces.
2. Crash payloads include the complete breadcrumb timeline leading up to the failure.
3. Errors are fingerprinted and grouped deterministically by root-cause call stacks.
4. Native crashes (SIGSEGV / NullPointerException) are caught by platform handlers and reported on the next launch.
