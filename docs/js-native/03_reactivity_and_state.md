# 03 — Reactivity & State Deep Dive

Bloom JS Native uses fine-grained Signals for reactivity. Signals are first-class reactive state primitives that track dependencies automatically and notify only the exact computations and DOM nodes that read them.

---

## 1. Writable Signals (`signal`)

A signal wraps a value and provides reactive read (`.value`) and write (`.value = ...`) capabilities:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Create signals
final count = signal(0);
final user = signal<String?>('Alex');
final items = signal<List<String>>(['Dart', 'Bloom']);

// Read signal value
print(count.value); // 0

// Mutate signal value
count.value = 1;
count.value += 5;
```

---

## 2. Computed Signals (`computed`)

A `computed` signal derives its value lazily from one or more dependency signals. It automatically re-evaluates only when its dependencies mutate, and memoizes its result:

```dart
final price = signal(100.0);
final quantity = signal(2);
final taxRate = signal(0.08);

// Automatically depends on [price] and [quantity]
final subtotal = computed(() => price.value * quantity.value);

// Automatically depends on [subtotal] and [taxRate]
final grandTotal = computed(() => subtotal.value * (1 + taxRate.value));

print(grandTotal.value); // 216.0

// Mutating a dependency updates derivatives lazily
quantity.value = 3;
print(grandTotal.value); // 324.0
```

---

## 3. Reactive Effects (`effect`)

An `effect` executes an asynchronous or synchronous side-effect whenever any of the signals read within its body change:

```dart
final searchQuery = signal('');

// Disposer function is returned
final dispose = effect(() {
  print('Fetching results for query: ${searchQuery.value}');
  // Perform search API call...
});

searchQuery.value = 'Bloom JS'; // Automatically triggers effect!

// Clean up effect when no longer needed
dispose();
```

---

## 4. Batching Mutations (`batch`)

When updating multiple signals consecutively, `batch()` defers all reactive downstream notifications until the batch callback finishes. This prevents intermediate calculations and unnecessary DOM reflows:

```dart
final firstName = signal('Ada');
final lastName = signal('Lovelace');

final fullName = computed(() => '${firstName.value} ${lastName.value}');

effect(() {
  print('Full Name is: ${fullName.value}');
});

// Without batch: prints twice (once for firstName, once for lastName)
// With batch: prints exactly once at the end of the block
batch(() {
  firstName.value = 'Grace';
  lastName.value = 'Hopper';
});
```

---

## 5. Untracked Reads (`untracked`)

To read a signal's value inside an effect or computed without subscribing to future changes, wrap the read in `untracked()`:

```dart
final activeTab = signal('home');
final telemetryId = signal(1234);

effect(() {
  // We want to re-run when [activeTab] changes...
  final tab = activeTab.value;

  // ...but do NOT re-run when [telemetryId] changes
  final id = untracked(() => telemetryId.value);

  print('User navigated to $tab (Session ID: $id)');
});
```

---

## 6. Scoped Memory Management (`_Region` & DOM Lifecycle)

In traditional frameworks, memory leaks occur when event listeners or reactive effects are attached to unmounted components.

Bloom JS Native uses **Hierarchical Cleanup Regions (`_Region`)**:
- When a `Live()`, `Show()`, or `ForEach()` node mounts, it creates an isolated `_Region`.
- All `effect()` subscriptions created inside that region are registered to it.
- When the DOM node is removed or replaced, `region.disposeAll()` terminates every effect, cancels listeners, and frees memory automatically.

```dart
// Zero memory leaks: effect is auto-disposed when Show toggles to false
Show(
  () => isModalOpen.value,
  child: Live(() => Div(
    text: 'Modal Active. Global counter: ${globalCounter.value}',
  )),
)
```
