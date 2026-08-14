# 04. State Management & Controllers

## 1. The 5-Tier State Architecture

Bloom organizes application state into five well-defined categories:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Local / UI State (Transient widget state, e.g. toggles)   │
├─────────────────────────────────────────────────────────────┤
│ 2. Application State (Global client state, e.g. theme/cart)  │
├─────────────────────────────────────────────────────────────┤
│ 3. Session State (Auth tokens, active user profile)         │
├─────────────────────────────────────────────────────────────┤
│ 4. Server State (Remote async query data & caching)          │
├─────────────────────────────────────────────────────────────┤
│ 5. Persisted State (Local key-value / offline database)     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Fine-Grained Reactivity (Signals Engine)

Bloom wraps the battle-tested `signals` Dart runtime. This provides synchronous, fine-grained, dependency-tracking reactivity without widget rebuild overhead.

### 2.1 Primitive Signals

```dart
import 'package:bloom_framework/bloom.dart';

// Create a reactive value
final count = signal(0);

// Read and write
print(count.value); // 0
count.value++;      // 1
```

### 2.2 Computed Values (Derived State)

Computed signals evaluate lazily and update automatically when their dependencies change:

```dart
final price = signal(29.99);
final quantity = signal(2);

final total = computed(() => price.value * quantity.value);

print(total.value); // 59.98
quantity.value = 3;
print(total.value); // 89.97
```

### 2.3 Side Effects

Effects run immediately and re-run whenever any read signal mutates:

```dart
final dispose = effect(() {
  logger.info('Current count is: ${count.value}');
});

// Call dispose() when done
```

---

## 3. Flutter Widget Integration

Bloom provides ergonomic widget helpers that listen to signal changes with zero boilerplate:

### Option A: `Watch` Widget (Fine-Grained Scoping)

```dart
class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = inject<CounterController>();

    return Scaffold(
      body: Center(
        child: Watch((context) {
          // Only this text widget rebuilds when count changes
          return Text('Count: ${controller.count.value}');
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Option B: `.watch(context)` Extension

```dart
class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = inject<AuthController>().currentUser.watch(context);

    if (user == null) return const CircularProgressIndicator();
    return Text('Hello, ${user.name}!');
  }
}
```

---

## 4. The Controller Model

Bloom controllers encapsulate domain logic and expose reactive state:

```dart
// lib/features/counter/controllers/counter_controller.dart
import 'package:bloom_framework/bloom.dart';

class CounterController extends BloomController {
  final count = signal(0);
  late final isEven = computed(() => count.value.isEven);

  void increment() => count.value++;
  void decrement() => count.value--;
  void reset() => count.value = 0;

  @override
  void onInit() {
    super.onInit();
    logger.info('CounterController initialized');
  }

  @override
  void onDispose() {
    logger.info('CounterController disposed');
    super.onDispose();
  }
}
```

### Progressive Architecture
* **Simple App:** Use standalone `signal()` definitions directly in widgets or route files.
* **Complex App:** Group logic into `BloomController` classes, inject via DI (`inject<T>()`), and communicate with services and repositories.

---

## 5. Ecosystem Compatibility: Riverpod & Bloc

Bloom prioritizes **Signals** as its default, first-class reactive model.

To support existing codebases and team preferences, Bloom provides adapter bridges:

```text
                  Bloom State API
                         │
        ┌────────────────┼────────────────┐
        │ (Default)      │ (Adapter)      │ (Adapter)
     Signals          Riverpod           Bloc
```

> **Note:** Adapters are compatibility layers for interoperability, not competing first-class mental models within the core framework.
