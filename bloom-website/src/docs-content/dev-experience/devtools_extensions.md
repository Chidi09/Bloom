# 33. Flutter DevTools Integration & VM Service Extensions

Bloom integrates directly with Flutter DevTools, exposing custom VM service extension RPC methods to inspect and manipulate framework state at runtime.

---

## 🔌 Registered VM Service Extensions

During `Bloom.boot()`, `BloomDevToolsService.register()` automatically exposes four custom RPC methods under the `ext.bloom.*` namespace:

### 1. `ext.bloom.getQueryCache`
Returns an array of all active query cache entries in `BloomData`, including staleness flags, TTL expiration timestamps, and cache keys:
```json
{
  "entries": [
    {
      "key": "users:detail:42",
      "isStale": false,
      "staleTimeMs": 300000,
      "hasData": true
    }
  ],
  "entryCount": 1
}
```

### 2. `ext.bloom.getContainerInfo`
Returns a JSON object mapping all registered Dependency Injection bindings in `BloomContainer` with their lifecycle types (singleton, factory, value):
```json
{
  "DatabaseService": "singleton (instantiated: true)",
  "UuidGenerator": "factory",
  "BloomConfig": "value"
}
```

### 3. `ext.bloom.getRouterState`
Returns the current route location, path pattern, path parameters, and query parameters from `BloomRouter`:
```json
{
  "location": "/products/42",
  "path": "/products/:id",
  "pathParameters": {"id": "42"},
  "queryParameters": {}
}
```

### 4. `ext.bloom.clearCache`
Clears all cached server queries in `BloomData` and forces all active `Watch` widgets to refetch fresh data from the network.

---

## 🪟 In-App Visual Inspector (`BloomDevOverlay`)

Mount `BloomDevOverlay` at the root of your application (included by default in `BloomApp` debug builds) to get a floating in-app diagnostic dashboard:

```dart
BloomApp(
  title: 'My Bloom App',
  routes: routes,
  home: const HomeScreen(),
)
```

Tap the overlay badge to view:
* Real-time query cache telemetry and cache invalidation buttons.
* Registered DI singleton statuses.
* Active navigation stack and route guards.
* Remote Dev Server synchronization status.
