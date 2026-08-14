# 2. 5-Minute Quickstart

Build and run your first full-stack reactive Bloom application in under five minutes.

---

## Step 1: Create a New Project

Run `bloom create` to scaffold a modern Bloom application:

```bash
bloom create quickstart_app
cd quickstart_app
```

---

## Step 2: Add a Controller with Signals Reactivity

Create a reactive state controller using `bloom generate controller`:

```bash
bloom generate controller counter
```

This creates `lib/features/counter/counter_controller.dart`. Replace its content with:

```dart
// lib/features/counter/counter_controller.dart
import 'package:bloom_framework/bloom.dart';

class CounterController extends BloomController {
  late final count = createSignal<int>(0, debugLabel: 'counter.count');

  void increment() {
    count.value++;
  }

  void decrement() {
    if (count.value > 0) {
      count.value--;
    }
  }

  void reset() {
    count.value = 0;
  }
}
```

---

## Step 3: Create a Filesystem Route

Generate a new page route at `/counter`:

```bash
bloom generate route counter
```

This generates `lib/routes/counter.dart`. Open the file and connect the controller and UI:

```dart
// lib/routes/counter.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import '../features/counter/counter_controller.dart';

class CounterRoute extends StatelessWidget {
  const CounterRoute({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolve controller via Bloom DI
    final controller = inject<CounterController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloom Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.reset,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Current Count:',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Rebuilds ONLY this text widget when controller.count updates
            Watch((context) => Text(
              '${controller.count.value}',
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
            )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: controller.decrement,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: controller.increment,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Step 4: Register Controller in Application Bootstrapper

Open `lib/app/boot.dart` and register `CounterController` in Bloom's dependency injection container:

```dart
// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';
import '../features/counter/counter_controller.dart';

class AppBootstrapper implements BloomBootstrapper {
  @override
  Future<void> onBoot(BloomContainer container) async {
    // Register CounterController as a lazy singleton
    container.provideSingleton<CounterController>((c) => CounterController());
  }
}
```

---

## Step 5: Launch the Development Server

Start Bloom's interactive developer server:

```bash
bloom dev
```

### Hot Reload & Interactive Controls
Once launched, use interactive keyboard shortcuts directly in your terminal:
* Press <kbd>r</kbd> — Trigger **Hot Reload**.
* Press <kbd>R</kbd> — Trigger **Hot Restart**.
* Press <kbd>w</kbd> — Toggle **Wireless QR Code** for mobile device pairing with **Bloom Go**.
* Press <kbd>d</kbd> — Open **Flutter DevTools**.
* Press <kbd>c</kbd> — Clear terminal output.
* Press <kbd>q</kbd> — Quit development session.
