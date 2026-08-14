# 20. Query Cache & Garbage Collection (`BloomData`)

Bloom Data provides a centralized memory and persistence cache manager with declarative key matching, prefix invalidations, automatic TTL garbage collection, and DevTools telemetry.

---

## 🔑 Cache Key Normalization

Cache keys in Bloom are declared as hierarchical `List<dynamic>` segments:

```dart
['users', 'list', {'status': 'active'}]
```

`BloomData` normalizes key arrays into deterministic string hashes (e.g. `users:list:{status: active}`), ensuring that identical objects with different property orders map to the exact same cache slot.

---

## 🧹 Prefix-Based Cache Invalidation

Invalidate any single query or group of related queries by matching key prefixes:

```dart
// Invalidate a specific user profile
BloomData.invalidateQueries(['users', 'detail', '42']);

// Invalidate ALL queries starting with ['users'] (lists, details, counts)
BloomData.invalidateQueries(['users']);
```

---

## ⏱️ Automatic TTL Garbage Collection

To prevent unbounded memory growth in long-running mobile apps, `BloomData` runs a background garbage collector:

* **Started automatically:** `Bloom.boot()` launches the periodic GC timer (`BloomData.startGarbageCollector()`).
* **Cleanup Strategy:** Inspects all cache entries. Any query whose `cacheTime` has expired and currently has zero active UI listeners is evicted from memory.
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
