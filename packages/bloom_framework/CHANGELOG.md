# Changelog

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
