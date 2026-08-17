# Changelog

## 0.2.1

### Fixed

* **`BloomEnv` crashed on first read of any unset key**: `get`/`getOrNull`/`getInt`/`getDouble`/`getBool`/`contains` fell back to `bool.hasEnvironment(key)` with a runtime `key`, but that constructor only accepts a compile-time constant — every call threw `bool.hasEnvironment can only be used as a const constructor` the moment a requested key wasn't already loaded into the runtime map. Since routes commonly read config on their very first build, this could blank the initial frame. The dynamic dart-define fallback is removed; apps that need `--dart-define` values now seed them explicitly at boot via the new `BloomEnv.loadDartDefines(...)`, using literal keys the same way `Bloom.boot()` already does for `BLOOM_FLAVOR`.
* **Scaffolded apps and the dev overlay showed a generic purple Material icon (`Icons.local_florist_rounded`) instead of the Bloom brand mark**: added a real `BloomLogo` widget that renders the actual five-petal gradient flower (matching `bloom-logo.tsx`) and swapped it in across the CLI scaffold template, the dev inspector overlay, and both example apps.

## 0.2.0

### Breaking

* **Canonical cache-key normalization**: `BloomData.normalizeKey` now canonicalizes recursively — `Map` segments have their entries sorted, and `Iterable` segments are canonicalized element-wise. Keys whose map segments differed only by insertion order previously resolved to *different* cache slots and now correctly resolve to the same one. Any code that persisted or compared the raw output of `normalizeKey` must be re-keyed.

### Fixed

* **Invalidation reached only cached queries**: `BloomData.invalidateQueries` signalled only queries that already held a cache entry, so a query that had never completed a successful fetch (still loading, or in the error state) was never notified. Calling `invalidate()` on a failed query is now a working retry path. Prefix matching is evaluated on `:` segment boundaries, so `['users']` matches `['users','detail','42']` but not `['usersettings','1']`.
* **Garbage collection could deafen live queries**: expired entries were evicted and their invalidation stream controllers closed without regard for active subscribers, permanently stopping a mounted query from receiving invalidations. Eviction now requires a zero listener count, and a controller is never closed while a listener is attached. The same guard now covers `getEntry()`, `getQueryData()` and `removeEntry()`, which each closed controllers as a side effect of reading or removing an expired entry.

### Added

* **`BloomData.releaseListener(key)`**: releases a listener slot acquired via `BloomData.onInvalidated(key)`. `BloomQuery.dispose()` calls it automatically, so it is only needed when subscribing to `onInvalidated` directly.

## 0.1.0

* **Core Runtime & Boot Lifecycle**: Single-call `Bloom.boot()` with dependency injection container (`inject<T>()`, `provideSingleton<T>()`).
* **Signals State Management**: High-performance fine-grained reactivity (`signal`, `computed`, `effect`, `batch`, `Watch`, `SignalBuilder`).
* **Filesystem Routing**: File-based route conventions (`index.dart`, `[id].dart`, `_layout.dart` ShellRoutes, route guards).
* **Bloom Data & Offline Engine**: Stale-while-revalidate caching (`BloomData.query`, `BloomData.mutation`), deduplication, TTL GC, and `OfflineMutationQueue`.
* **Native Architecture & Prebuild**: Declarative native plugin integrations (`BloomPermissions`, `BloomSecureStorage`, `BloomNotifications`, `BloomCamera`, `BloomDeepLinks`).
* **DevTools & Dev Server**: UDP broadcast discovery on port 5354, visual DevTools overlay, `BloomNetworkInspector` with request replay.
* **Full-Stack Server & SSR Engine**: `BloomApiRouter`, `BloomRequest`, `BloomResponse`, API route handlers, and middleware.
* **Observability & Error Telemetry**: Automatic crash capture, breadcrumbs timeline, symbol packaging, and fingerprinting.
* **Full-Stack Adapters**: Official Supabase and Serverpod client & repository adapters.
