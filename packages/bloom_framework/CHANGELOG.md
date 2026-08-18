# Changelog

## 0.3.0

### Added

* **Automatic OpenAPI 3.1 & Swagger / Scalar Documentation**: `BloomApiRouter` now includes `enableOpenApi()` and `toOpenApiSpec()` for zero-config, single-line API documentation generation. The router automatically discovers registered routes, parameters, HTTP methods, and tags, rendering interactive **Scalar** (`/api/docs`) and **Swagger UI** (`/api/swagger`) consoles with official Bloom vector branding and dark mode styling.
* **HTTP HEAD Method Support for GET Routes**: `BloomApiRouter` now transparently supports `HEAD` requests on all `GET` endpoints, returning accurate headers and status codes without body serialization.

### Changed

* **Bloom API Router Specificity & Regex Matching**: Fixed root `/` path matching and wildcard resolution.

### Added

* **Prerender readiness signal for headless-browser SSG/SSR**: `BloomApp` now enables Flutter's semantics/accessibility tree and signals `window.__BLOOM_PRERENDER_READY__` after its first frame, on web only (no-op elsewhere). This is consumed by `bloom_cli`'s new real headless-Chromium prerendering pipeline (`bloom build web --static`/`--server`) to know when a page has actually finished rendering before capturing its DOM.

## 0.2.2

### Fixed

* **`BloomRequest.params` defaulted to a `const {}` map**: any middleware that tried to attach convenience context (e.g. `bloom_i18n`'s resolved locale, `bloom_auth_server`'s verified `auth_user_id`/`auth_roles`) on a request with no path parameters crashed with `Unsupported operation: Cannot modify unmodifiable map` the moment it ran. `params` now always defaults to a fresh mutable map.
* **`BloomApiRouter` discarded per-request middleware context on every route match**: route dispatch built a *new* `BloomRequest` via `copyWith(params: ...)` after global middlewares had already run and attached state (params, or framework-internal `Expando`-backed context) to the original request instance — silently dropping it before route-specific middlewares and the handler ever saw it. Path parameters are now merged into the same request instance in place, so global middleware state (locale resolution, auth claims, etc.) survives all the way to the handler.
* **A pure-Dart server importing `bloom_server.dart` transitively pulled in `package:flutter`**: `bloom_realtime`'s single barrel exported both server-side (`BloomChannelHub`) and Flutter-app-only (`RealtimeQueryBridge`, which depends on `BloomData`'s `signals_flutter`-backed reactivity) code together, so any backend depending on it could not run under a plain `dart run`/`dart compile`. Split into `bloom_realtime.dart` (server-safe) and `bloom_realtime_client.dart` (Flutter client extras). Added a new Flutter-independent `bloom_core.dart` barrel (env config, DI container, logger) re-exported from `bloom_server.dart`, and a `bloom_data.dart` barrel for the client query/cache layer — server code should never import `bloom.dart` directly.

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
