# Bloom Hardening Spec Conventions & Definition of Done

> **Why this exists:** Phases 9–13 shipped with a recurring set of implementation defects that survived review because the acceptance criteria were vague and the anti-patterns were never written down. This document is the shared contract every phase **must** satisfy. When in doubt, this document wins over any individual phase doc.

---

## 🚫 Anti-Patterns (a phase is NOT done if any of these appear)

### A1. Print-only / no-op stubs
A command or API that prints "✔ success" without performing the work is a **defect**, not a placeholder.

- ❌ `bloom symbols upload` printing "✔ Symbols uploaded successfully" with no HTTP request.
- ❌ A `run()` that returns `0` after only `print(...)`.
- ✅ The command must perform the actual side effect and return a non-zero exit code on failure.

### A2. Hardcoded version/identity strings
`bloomVersion`, `flutterVersion`, `dartVersion`, `channel`, `buildNumber`, `activePatchId` must be **derived** from config/build metadata. Never literal `'1.0.0'`, `'3.27.0'`, `'production'`.

- ❌ `'flutterVersion': '3.27.0'`, `'channel': 'production'`.
- ✅ Read from `bloom.yaml`, `pubspec.lock`, the resolved framework package, or the build toolchain.

### A3. Dead flags / fields / functions
Every config flag, public field, and public function must be **consumed** somewhere. A flag that is declared but never read is a defect.

- ❌ `autoCaptureNativeCrashes` declared but never referenced in `initialize()`.
- ❌ `hashTokens()` defined but never called; a model field never serialized.
- ✅ Either wire it end-to-end or delete it.

### A4. Silent catch-swallow
`catch (_) {}` or `catch (e) { /* nothing */ }` that hides a real failure is a defect — especially `MissingPluginException` (native channel absent) and transport/network failures.

- ❌ Catching `MissingPluginException` and logging at `debug` while reporting "initialized".
- ✅ Log at `error`, rethrow, or fail explicitly; never claim success on a swallowed failure.

### A5. Non-deterministic output
Any hash, lockfile, manifest, or archive must **sort** all inputs before combining. File enumeration order is filesystem-dependent and must never leak into output.

- ❌ `listSync(recursive: true)` iterated unsorted into a hash/archive.
- ✅ Sort by a stable key (path, name) before hashing/concatenating.

### A6. Cross-component drift
A value computed in **two places** (e.g. runtime vs CLI) will diverge. There must be exactly **one canonical source** for any value that must match across components.

- ❌ Runtime fingerprint computed in `BloomRuntimeFingerprint.fromConfig()` and CLI fingerprint in `FingerprintGenerator.computeFingerprint()` using different inputs (modules, permissions source, Dart SDK).
- ✅ Generate the value once at build time (`fingerprint.g.dart` / build metadata) and consume that exact value everywhere.

---

## ✅ Definition of Done (every phase)

1. **Every acceptance criterion is testable** and has at least one automated test that asserts it.
2. **Generated code is executed**, not just string-matched. Any generated `server.dart` / `.g.dart` / template must be compiled (or run) in at least one test — string-containment assertions are insufficient.
3. **Every defect found in review gets a regression test** before the fix is accepted.
4. **Static analysis is clean**: `flutter analyze` (framework) and `dart analyze` (CLI) report 0 issues.
5. **All four packages pass**: `bloom_framework`, `bloom_cli`, `examples/bloom_counter`, `apps/bloom_go`.
6. **Error handlers chain and restore**: any hook into `FlutterError.onError` / `PlatformDispatcher.onError` must call the original handler and restore it (including a `null` original) on reset.
7. **Async teardown is awaited**: `close()` / `dispose()` / `reset()` returning `Future<void>` must be awaited, not fire-and-forget.

---

## 🧪 Acceptance Criteria Format (required for every phase)

Each criterion must be written as a **specific, observable, testable** statement with an explicit **negative** (what must NOT happen). Vague criteria like "native crashes are caught" are not acceptable.

Use this template:

```markdown
### C1. <Title>
- **When** <trigger>
- **Then** <observable result>
- **Must not** <negative behavior>
- **Test** <the test/command that verifies it>
```

---

## 🔗 Cross-Cutting Invariants

1. **Fingerprint parity** — the runtime fingerprint attached to telemetry/OTA events must byte-for-byte equal the CLI-generated `kBloomRuntimeFingerprint` (single canonical source; see A6).
2. **Deterministic ordering** — every hash, lockfile, manifest, and archive is sorted (see A5).
3. **No fake success** — every CLI command and network operation either performs its side effect or returns non-zero (see A1, A4).
4. **Identity is derived, never literal** — all version/channel/build identity comes from config or build metadata (see A2).
