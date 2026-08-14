# 03. Boot, Lifecycle & Dependency Injection

## 1. The Boot Sequence

Bloom provides a clean, single-call boot mechanism that prepares all necessary runtime subsystems before the Flutter widget tree mounts.

```dart
// lib/main.dart
import 'package:flutter/widgets.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/app.dart';

Future<void> main() async {
  // Single entry-point initializes environment, DI, config, and logging
  await Bloom.boot();

  runApp(const MyApp());
}
```

---

## 2. Boot Pipeline Execution Order

```text
1. WidgetsFlutterBinding.ensureInitialized()
                    ↓
2. Load bloom.yaml Configuration
                    ↓
3. Resolve & Parse Environment (.env, .env.local)
                    ↓
4. Initialize Structured Logging Subsystem
                    ↓
5. Initialize Dependency Injection Container
                    ↓
6. Register Framework Lifecycle Listeners
                    ↓
7. Execute App-Level Pre-Run Hooks (lib/app/boot.dart)
                    ↓
8. Mount Flutter Widget Tree (runApp)
```

---

## 3. Application Boot Hooks

Custom initialization logic lives in `lib/app/boot.dart`:

```dart
// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';
import '../features/auth/services/auth_service.dart';
import '../services/api_client.dart';

class AppBootstrapper extends BloomBootstrapper {
  @override
  Future<void> onBoot(BloomContainer container) async {
    // Register dependencies
    container.provide<ApiClient>(() => ApiClient());
    container.provideSingleton<AuthService>(() => AuthService(inject()));

    // Custom async startup operations
    final auth = inject<AuthService>();
    await auth.restoreSession();
  }
}
```

---

## 4. Dependency Injection (DI)

### 4.1 Why DI Belongs in Core (v0.1)
Routing guards require authentication services; authentication services require API clients; API clients require environment configuration. Thus, a robust yet lightweight DI container is foundational before routing can operate.

```text
Router Guards
     ↓
Require AuthService
     ↓
AuthService Requires ApiClient
     ↓
DI Container is Essential at Boot
```

### 4.2 Developer API

Bloom exposes a clean, functional API that abstracts container mechanics:

```dart
// Registering dependencies
provide<Logger>(() => ConsoleLogger());                      // Transient factory
provideSingleton<Database>(() => AppDatabase());             // Eager / Lazy Singleton
provideValue<AppConfig>(config);                            // Existing instance

// Resolving dependencies
final api = inject<ApiClient>();
final auth = inject<AuthService>();

// Optional resolution (returns null if not registered)
final analytics = injectOrNull<AnalyticsService>();
```

### 4.3 Testing Overrides
Bloom's DI container enables simple mock overrides without touching production code:

```dart
test('AuthService login test', () async {
  final container = Bloom.createTestContainer();
  container.override<ApiClient>(MockApiClient());

  final auth = container.get<AuthService>();
  await auth.login('user', 'pass');
  expect(auth.isAuthenticated.value, isTrue);
});
```

---

## 5. Application Lifecycle & Observers

Bloom integrates seamlessly with Flutter's `AppLifecycleListener` and provides fine-grained hooks:

```dart
class SessionManager with BloomLifecycleObserver {
  @override
  void onAppResumed() {
    logger.info('App came to foreground — refreshing stale queries');
    BloomData.refreshStaleQueries();
  }

  @override
  void onAppPaused() {
    logger.info('App backgrounded — flushing dirty storage buffers');
    inject<StorageService>().flush();
  }

  @override
  void onAppDetached() {
    logger.info('App terminating');
  }
}
```
