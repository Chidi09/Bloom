# 42. Architectural Best Practices & Design Conventions

Guidelines for structuring large-scale, maintainable applications with the Bloom Framework.

---

## 📁 1. Recommended Directory Structure

Structure features by domain rather than by technical layer:

```text
lib/
├── app/                        # Global bootstrapper, theme, router output
├── config/                     # Static constants, design tokens
├── features/                   # Domain features
│   ├── auth/
│   │   ├── auth_controller.dart
│   │   ├── auth_service.dart
│   │   └── widgets/
│   └── catalog/
│       ├── catalog_controller.dart
│       ├── models/
│       └── widgets/
└── routes/                     # UI Page entry points mapping directly to URLs
    ├── index.dart
    └── (auth)/
        ├── login.dart
        └── register.dart
```

---

## 🎮 2. Controller Granularity & Scope

* **One controller per feature domain:** Avoid monolithic "GlobalAppController" god classes. Keep controllers focused on a single bounded domain (e.g. `CartController`, `ProfileController`).
* **Use `createSignal` and `createComputed`:** Register signals using controller helper methods so their memory is automatically released on `onDispose()`.
* **Expose read-only signals for public consumption:** Keep internal writable signals private (`_count`) and expose read-only views (`count => _count.readonly()`) to prevent unexpected external state mutations.

---

## 🔑 3. Query Cache Key Design

* Use hierarchical string and map segments: `['domain', 'action', id, {filter: value}]`.
* Group related entities under common prefixes so `BloomData.invalidateQueries(['domain'])` invalidates all stale variations in a single call.

---

## 🛡️ 4. Guard Design & Navigation

* Keep route guards fast and synchronous or lightweight asynchronous.
* Use `BloomAuthGuard` for standard authentication protection.
* Return `GuardResult.allow()` for permitted access and `GuardResult.redirect('/path')` for unauthorized matches.

---

## 🪵 5. Structured Logging & Telemetry

* Avoid raw `print()` statements in production code. Use `logger.info()`, `logger.debug()`, and `logger.error()`.
* Use contextual child loggers (`logger.child('PAYMENTS')`) to easily filter log output in CI or remote error reporting consoles.
