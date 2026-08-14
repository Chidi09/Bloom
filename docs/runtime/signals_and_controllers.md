# 14. Reactive State: Signals & Controllers

Bloom utilizes fine-grained reactive **Signals** powered by `signals_flutter`. Signals eliminate widget tree rebuild overhead by updating only the exact text, button, or container widget that reads the value.

---

## ⚡ Core Reactive Primitives

### 1. `signal<T>(initialValue)`
A mutable reactive value:
```dart
final count = signal<int>(0, debugLabel: 'counter.count');

print(count.value); // 0
count.value = 5;    // Automatically notifies reactive listeners
```

### 2. `computed<T>(computeFn)`
A derived, memoized value that only recalculates when upstream signals change:
```dart
final firstName = signal('Ada');
final lastName = signal('Lovelace');

final fullName = computed(() => '${firstName.value} ${lastName.value}');
print(fullName.value); // 'Ada Lovelace'
```

### 3. `effect(callback)`
A side-effect that executes immediately and re-runs whenever any read signal mutates:
```dart
final disposeEffect = effect(() {
  print('Current count is: ${count.value}');
});

// Clean up when no longer needed
disposeEffect();
```

### 4. `batch(callback)`
Batches multiple signal mutations into a single subscriber notification pass:
```dart
batch(() {
  firstName.value = 'Grace';
  lastName.value = 'Hopper';
}); // Subscribers notify only ONCE after batch finishes
```

### 5. `signal.readonly()`
Exposes an immutable read-only view of a signal:
```dart
ReadonlySignal<int> get publicCount => _count.readonly();
```

---

## 🖼️ UI Binding with `Watch` and `SignalBuilder`

### `Watch` Widget (Recommended)
Automatically tracks any signals read within its builder and rebuilds only itself:

```dart
Watch((context) {
  return Text(
    'Total items: ${cartController.itemCount.value}',
    style: Theme.of(context).textTheme.headlineMedium,
  );
})
```

### `SignalBuilder` Widget
Explicitly binds to a specific signal:

```dart
SignalBuilder<int>(
  signal: counter.count,
  builder: (context, value, child) {
    return Text('Count: $value');
  },
)
```

---

## 🎮 `BloomController` Architecture

Controllers encapsulate domain business logic, reactive state, and side-effects:

```dart
// lib/features/todos/todo_controller.dart
import 'package:bloom_framework/bloom.dart';

class Todo {
  final String id;
  final String title;
  final bool isCompleted;

  const Todo({required this.id, required this.title, this.isCompleted = false});
}

class TodoController extends BloomController {
  // Signals tracked by controller
  late final todos = createSignal<List<Todo>>([], debugLabel: 'todo.list');
  late final filter = createSignal<String>('all', debugLabel: 'todo.filter');

  // Computed filtered list
  late final filteredTodos = createComputed<List<Todo>>(() {
    final list = todos.value;
    final activeFilter = filter.value;
    if (activeFilter == 'completed') return list.where((t) => t.isCompleted).toList();
    if (activeFilter == 'active') return list.where((t) => !t.isCompleted).toList();
    return list;
  });

  @override
  void onInit() {
    super.onInit();
    // Add lifecycle-managed effect (automatically disposed when controller is destroyed)
    addEffect(() {
      logger.debug('Todos updated. Total count: ${todos.value.length}');
    });
  }

  void addTodo(String title) {
    todos.value = [
      ...todos.value,
      Todo(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title),
    ];
  }

  void toggleTodo(String id) {
    todos.value = todos.value.map((t) {
      if (t.id == id) {
        return Todo(id: t.id, title: t.title, isCompleted: !t.isCompleted);
      }
      return t;
    }).toList();
  }

  @override
  void onDispose() {
    logger.info('TodoController disposed.');
    super.onDispose();
  }
}
```

---

## 🔄 `BloomController` Lifecycle Methods

| Method | Description |
| :--- | :--- |
| `onInit()` | Invoked when the controller is instantiated. Ideal for subscribing to streams or triggering initial queries. |
| `createSignal<T>()` | Registers a signal whose memory is tracked by this controller. |
| `createComputed<T>()` | Registers a computed signal. |
| `addEffect()` | Attaches an effect that is automatically cancelled upon `dispose()`. |
| `onDispose()` | Invoked when `dispose()` is called on the controller. |
