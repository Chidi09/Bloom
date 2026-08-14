# 19. Asynchronous Mutations & Optimistic Updates

`BloomMutation<T, P>` manages asynchronous data modifications (creates, updates, deletes), providing optimistic updates with automated state rollback on failure.

---

## ⚡ Creating a Mutation

```dart
import 'package:bloom_framework/bloom.dart';

final createTodoMutation = BloomData.mutation<Todo, String>(
  mutationFn: (newTitle) async {
    final res = await http.post('/api/todos', body: {'title': newTitle});
    return Todo.fromJson(res);
  },
  onSuccess: (newTodo, newTitle, context) {
    logger.info('Todo created on server: ${newTodo.id}');
    // Invalidate query cache so list refreshes
    BloomData.invalidateQueries(['todos']);
  },
  onError: (err, newTitle, context) {
    logger.error('Failed to create todo: $err');
  },
);
```

---

## 🚀 Optimistic Updates & Rollback Pattern (Worked Example)

Optimistic UI updates give users instant feedback by updating local signals before the backend request completes. If the backend fails, the previous state is restored automatically:

```dart
final updateTodoStatusMutation = BloomData.mutation<Todo, ({String id, bool isCompleted})>(
  mutationFn: (param) async {
    final res = await http.patch('/api/todos/${param.id}', body: {'completed': param.isCompleted});
    return Todo.fromJson(res);
  },
  // 1. Executed immediately before the network request starts
  onMutate: (param) {
    // Snapshot previous cache state
    final previousTodos = todoListQuery.data.value ?? [];

    // Optimistically update query cache immediately
    final updatedList = previousTodos.map((t) {
      if (t.id == param.id) {
        return t.copyWith(isCompleted: param.isCompleted);
      }
      return t;
    }).toList();

    todoListQuery.setData(updatedList);

    // Return context map containing the rollback snapshot
    return {'rollback': previousTodos};
  },
  // 2. Executed ONLY if the mutation throws an exception
  onError: (error, param, context) {
    logger.warn('Server update failed, rolling back UI...');
    if (context != null && context['rollback'] != null) {
      final previous = context['rollback'] as List<Todo>;
      todoListQuery.setData(previous);
    }
  },
  // 3. Executed always after success or failure
  onSettled: (result, error, param, context) {
    BloomData.invalidateQueries(['todos']);
  },
);
```

---

## 📊 Reactive Mutation Signals

| Signal Accessor | Type | Description |
| :--- | :--- | :--- |
| `mutation.isLoading` | `ReadonlySignal<bool>` | `true` while the mutation network call is in flight. |
| `mutation.isSuccess` | `ReadonlySignal<bool>` | `true` if the last mutation completed successfully. |
| `mutation.isError` | `ReadonlySignal<bool>` | `true` if the last mutation failed. |
| `mutation.data` | `ReadonlySignal<T?>` | Response payload from the last successful mutation. |
| `mutation.error` | `ReadonlySignal<Object?>` | Error object from the last failed mutation. |

---

## 🎯 Triggering a Mutation

```dart
// Fire-and-forget
createTodoMutation.mutate('Buy groceries');

// Awaitable asynchronous result
try {
  final newTodo = await createTodoMutation.mutateAsync('Buy groceries');
  print('Created: ${newTodo.id}');
} catch (e) {
  print('Caught error: $e');
}
```
