# 18. Asynchronous Server Queries (`BloomQuery`)

Bloom Data provides a TanStack-style query engine designed for fetching, caching, deduplicating, and synchronizing server state with zero boilerplate.

---

## ⚡ Creating a Query

Declare a query by passing a cache key and an asynchronous fetcher function:

```dart
import 'package:bloom_framework/bloom.dart';

final userQuery = BloomData.query<User>(
  queryKey: ['users', 'detail', userId],
  queryFn: () async {
    final response = await http.get('/api/users/$userId');
    return User.fromJson(response);
  },
  staleTime: const Duration(minutes: 5),
  cacheTime: const Duration(hours: 1),
  retryCount: 3,
);
```

---

## 📊 Reactive Query State Accessors

`BloomQuery<T>` exposes reactive signals:

| Signal Accessor | Type | Description |
| :--- | :--- | :--- |
| `query.data` | `ReadonlySignal<T?>` | Cached or fetched query payload. |
| `query.isLoading` | `ReadonlySignal<bool>` | `true` while the query is actively fetching for the first time. |
| `query.isFetching` | `ReadonlySignal<bool>` | `true` during initial fetch or background revalidation. |
| `query.isError` | `ReadonlySignal<bool>` | `true` if the fetcher threw an exception. |
| `query.error` | `ReadonlySignal<Object?>` | The caught error object, if any. |
| `query.status` | `ReadonlySignal<BloomQueryStatus>` | Current status enum (`idle`, `loading`, `success`, `error`). |

---

## 🖼️ UI Consumption with `Watch`

```dart
Widget build(BuildContext context) {
  return Watch((context) {
    if (userQuery.isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userQuery.isError.value) {
      return Center(
        child: Text('Error: ${userQuery.error.value}'),
      );
    }

    final user = userQuery.data.value;
    if (user == null) return const Text('No user found');

    return Text('Welcome, ${user.name}!');
  });
}
```

---

## 🔄 Programmatic Query Control

### 1. Manual Refetch
```dart
await userQuery.refetch();
```

### 2. Manual Invalidation
Marks the query as stale and triggers immediate background refetch for active queries (including queries in an error or initial loading state with no existing cache entry):
```dart
userQuery.invalidate();
```

### 3. Direct Cache Mutation (`setData`)
Directly updates cached data without making a network request:
```dart
userQuery.setData(updatedUser);
```
