# 12. Framework Boot & Application Lifecycle

Bloom provides a deterministic, single-call bootstrapper that configures all subsystems, environment files, dependency injection bindings, deep link listeners, DevTools extensions, query cache garbage collection, and Over-The-Air code-push services before the first widget renders.

---

## 🚀 The `Bloom.boot()` Entry Point

Your application's `main()` entrypoint boots the framework asynchronously:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/app.dart';
import 'app/boot.dart';

void main() async {
  // Ensure engine binding is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Boot Bloom runtime services
  await Bloom.boot(
    bootstrapper: AppBootstrapper(),
    flavor: 'production', // Optional: defaults to String.fromEnvironment('BLOOM_FLAVOR')
  );

  runApp(const MyApp());
}
```

---

## ⚙️ Deterministic 10-Step Boot Sequence

When `Bloom.boot()` is called, it executes the following operations in exact chronological order:

```text
 1. Initialize Flutter WidgetsBinding
 2. Discover active flavor (from parameter or compile-time 'BLOOM_FLAVOR')
 3. Load BloomConfig from bloom.yaml asset or defaults
 4. Load & parse .env and .env.local environment variables
 5. Configure global BloomLogger with formatted console output
 6. Register core framework bindings in Dependency Injection (BloomConfig, etc.)
 7. Initialize Deep Links listener & cold-start route buffering
 8. Register VM DevTools Service extensions & start Cache Garbage Collector
 9. Initialize BloomOTA Code-Push runtime & background update check (if enabled)
10. Execute user AppBootstrapper.onBoot(container)
```

---

## 🛠️ The `BloomBootstrapper` Contract

Custom user startup logic, dependency registration, and authentication session restoration belong in `lib/app/boot.dart`:

```dart
// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';
import '../features/auth/auth_controller.dart';
import '../services/api_service.dart';

class AppBootstrapper implements BloomBootstrapper {
  @override
  Future<void> onBoot(BloomContainer container) async {
    logger.info('Running application bootstrapper...');

    // 1. Provide HTTP and Database Clients
    container.provideSingleton<ApiService>((c) => ApiService());

    // 2. Register State Controllers
    container.provideSingleton<AuthController>((c) => AuthController());
  }
}
```

---

## 📊 Runtime Inspection Accessors

The static `Bloom` class exposes runtime inspection properties:

| Property | Type | Description |
| :--- | :--- | :--- |
| `Bloom.isBooted` | `bool` | `true` once all 10 boot steps have completed successfully. |
| `Bloom.config` | `BloomConfig` | Strongly-typed configuration parsed from `bloom.yaml`. |
| `Bloom.activeFlavor` | `String?` | The active build flavor name (e.g. `'staging'`), or `null` if none. |
| `Bloom.container` | `BloomContainer` | Global dependency injection container instance. |

---

## 🔄 Resetting Runtime State in Tests

Between unit or integration tests, calling `Bloom.reset()` completely clears all memory, restores default configs, halts background timers, resets the DI container, and cleans up OTA controllers:

```dart
setUp(() {
  Bloom.reset();
});
```
