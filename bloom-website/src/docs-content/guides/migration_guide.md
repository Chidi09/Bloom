# 40. Migration Guide: From Vanilla Flutter to Bloom

This guide helps teams migrate existing Flutter codebases (using Riverpod, BLoC, standard GoRouter, or Dio) to Bloom's cohesive architecture.

---

## 🔄 State Management Migration

### 1. Migrating from Riverpod / StateNotifier to Signals
* **Riverpod:** `StateNotifierProvider`, `ref.watch()`, and `ConsumerWidget` boilerplate.
* **Bloom:** Plain Dart `BloomController` with `createSignal<T>()` and `Watch` widgets.

```dart
// BEFORE (Riverpod)
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => state++;
}
final counterProvider = StateNotifierProvider<CounterNotifier, int>((ref) => CounterNotifier());

// In Widget:
class CounterView extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

// AFTER (Bloom)
class CounterController extends BloomController {
  late final count = createSignal<int>(0);
  void increment() => count.value++;
}

// In Widget:
class CounterView extends StatelessWidget {
  Widget build(BuildContext context) {
    final ctrl = inject<CounterController>();
    return Watch((context) => Text('${ctrl.count.value}'));
  }
}
```

---

## 🗂️ Routing Migration

### 2. Migrating from Manual `GoRouter` to Filesystem Routes
* **Vanilla Flutter:** Manually maintained 300+ line `GoRouter` configuration in code.
* **Bloom:** Create individual files in `lib/routes/`. Bloom CLI automatically generates and updates `routes.g.dart`.

| Vanilla GoRouter | Bloom Filesystem Route |
| :--- | :--- |
| `GoRoute(path: '/', builder: ...)` | `lib/routes/index.dart` |
| `GoRoute(path: '/users/:id', builder: ...)` | `lib/routes/users/[id].dart` |
| `ShellRoute(builder: ...)` | `lib/routes/_layout.dart` |

---

## 🌐 Networking Migration

### 3. Migrating from `Dio` / `http` to `BloomData` Queries
* **Vanilla Flutter:** Manual `FutureBuilder`, loading state booleans, error catches, and in-memory Map caches.
* **Bloom:** `BloomData.query<T>()` handles deduplication, caching, staleness, and retries automatically.

```dart
// BEFORE (Vanilla)
class _UserScreenState extends State<UserScreen> {
  bool isLoading = true;
  User? user;

  void fetch() async {
    final res = await dio.get('/user/1');
    setState(() { user = User.fromJson(res.data); isLoading = false; });
  }
}

// AFTER (Bloom Data)
final userQuery = BloomData.query<User>(
  queryKey: ['user', 1],
  queryFn: () async => User.fromJson(await http.get('/user/1')),
);

// In Widget:
Watch((context) {
  if (userQuery.isLoading.value) return const CircularProgressIndicator();
  return Text(userQuery.data.value!.name);
})
```
