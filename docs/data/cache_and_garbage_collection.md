# 20. Query Cache & Garbage Collection (`BloomData`)

Bloom Data provides a centralized memory and persistence cache manager with declarative key matching, prefix invalidations, automatic TTL garbage collection, and DevTools telemetry.

---

## 🔑 Cache Key Normalization

Cache keys in Bloom are declared as hierarchical `List<dynamic>` segments:

```dart
['users', 'list', {'status': 'active', 'page': 1}]
```

`BloomData.normalizeKey` normalizes key arrays into deterministic string representations (e.g. `users:list:{page: 1, status: active}`). Key normalization is recursive and canonical:
* **Map segments:** Map entries are sorted alphabetically by key so that identical maps with different insertion orders (e.g. `{'status': 'active', 'page': 1}` and `{'page': 1, 'status': 'active'}`) resolve to the exact same cache slot.
* **Iterable segments:** `Iterable` and `List` elements are canonicalized element-wise (e.g. `[1, 2]`).
* **Nested structures:** Nested Maps and Iterables recurse through canonical normalization.

---

## 🧹 Prefix-Based Cache Invalidation

Invalidate any single query or group of related queries by matching key prefixes:

```dart
// Invalidate a specific user profile
BloomData.invalidateQueries(['users', 'detail', '42']);

// Invalidate ALL queries starting with ['users'] (lists, details, counts)
BloomData.invalidateQueries(['users']);
```

`BloomData.invalidateQueries` evaluates key matching on `:` segment boundaries:
* A prefix `['users']` matches `['users', 'detail', '42']` and `['users']`.
* A prefix `['users']` will **not** match `['usersettings', '1']`.

Invalidation signals both existing cache entries and all active registered invalidation listeners. This ensures queries that have not yet cached a successful result (such as queries in an error or initial loading state) still receive the invalidation signal and trigger revalidation.

---

## ⏱️ Automatic TTL Garbage Collection

To prevent unbounded memory growth in long-running mobile apps, `BloomData` runs a background garbage collector:

* **Started automatically:** `Bloom.boot()` launches the periodic GC timer (`BloomData.startGarbageCollector()`).
* **Cleanup Strategy:** Inspects all cache entries. Any query whose `cacheTime` has expired and currently has zero active UI listeners is evicted from memory. Invalidation stream controllers are never closed while active listeners remain attached.
* **Listener-Aware Tracking:** `BloomData.onInvalidated(key)` increments the active listener count for that key, while `BloomData.releaseListener(key)` decrements it. Disposing a `BloomQuery` (`query.dispose()`) automatically calls `releaseListener`, so manual listener management is only required when subscribing directly to `BloomData.onInvalidated`.
* **Expired Entry Read Behavior:** Calling `BloomData.getEntry(key)` or `BloomData.getQueryData(key)` on an expired entry removes it from cache as a side effect of reading it, disposing the controller only if no active listeners remain.
* **Halted on reset:** `Bloom.reset()` stops the background GC timer (`BloomData.stopGarbageCollector()`).

---

## 🔍 Telemetry & Cache Inspection

Query cache status can be inspected at runtime or dumped for DevTools:

```dart
// Current number of cached query entries
print(BloomData.entryCount);

// Full JSON dump of active cache entries and TTL expiration
final cacheDump = BloomData.dumpCache();
print(cacheDump);
// [
//   {
//     "key": "users:detail:42",
//     "staleTimeMs": 300000,
//     "isStale": false,
//     "hasData": true
//   }
// ]

// Completely clear all query cache entries
BloomData.clearCache();
```
