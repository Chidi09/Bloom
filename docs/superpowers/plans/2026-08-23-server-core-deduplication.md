# Server Core De-duplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the copy-pasted server and core source shared by `bloom_framework` and `bloom_server`, so each file has exactly one definition.

**Architecture:** `bloom_framework` takes a dependency on `bloom_server`, deletes its eleven duplicate files, and re-exports them from their single home. The dependency can only run in this direction: `bloom_framework` requires the Flutter SDK, while `bloom_server` is deliberately Flutter-free, so `bloom_server` must never depend on `bloom_framework`.

**Tech Stack:** Dart 3, `package:test`. No new runtime dependencies.

**Spec:** This document. It originates from an audit finding recorded in "Background" below.

## Background — why this exists

Eleven `.dart` files are **byte-identical** across the two packages. Verified against `HEAD`:

```
IDENTICAL  bloom_core.dart
IDENTICAL  src/config/env_schema.dart
IDENTICAL  src/core/env.dart
IDENTICAL  src/core/logger.dart
IDENTICAL  src/di/container.dart
IDENTICAL  src/di/scope.dart
IDENTICAL  src/server/api_router.dart          (603 lines)
IDENTICAL  src/server/bloom_middleware.dart
IDENTICAL  src/server/bloom_request.dart
IDENTICAL  src/server/bloom_response.dart      (131 lines)
DIVERGED   bloom_server.dart                    (barrel; server also exports rpc_mount)
SERVERONLY src/server/rpc_mount.dart
```

`bloom_server` has 12 `.dart` files total; `bloom_framework` has 90. So `bloom_server` is very nearly a strict subset.

The duplication is already causing harm:

- `rpc_mount.dart` exists **only** in `bloom_server`. The generated SSR server imports `package:bloom_framework/bloom_server.dart`, so it cannot mount an RPC router at all.
- Any change to the server core must be hand-applied twice. The streaming-responses plan is forced to carry `cp` + `diff` steps in every task purely to work around this.
- Nothing detects drift. The two copies are identical today by discipline alone.

## Direction of the dependency — why `bloom_framework` → `bloom_server`

This is the one design decision in the plan and it is forced, not chosen:

- `bloom_framework` (v0.3.1) depends on `flutter: sdk: flutter`, `flutter_test`, `signals_flutter`, `supabase_flutter`, `image_picker`, `flutter_secure_storage`, `permission_handler`, `flutter_local_notifications`, `shorebird_code_push`.
- `bloom_server` (v0.1.0) depends on exactly two packages: `bloom_js_native` and `bloom_seo`. It has **zero** Flutter dependencies, deliberately — `bloom_server/lib/bloom_core.dart` documents this contract in its header comment, and an earlier migration moved it from `signals` to `signals_core` specifically to keep it so.

If `bloom_server` depended on `bloom_framework`, every pure-Dart backend would require the Flutter SDK and `dart compile exe` would break. That reverses deliberate prior work. The dependency therefore runs `bloom_framework` → `bloom_server`, and this plan adds a regression test that fails if anyone reverses it.

**Rejected alternative:** extracting the shared files into a new `bloom_core` package that both depend on. It is semantically tidier — `bloom_framework` re-exporting DI and logging from a package named "server" reads oddly — but it churns all 11 packages that currently depend on `bloom_server` and adds a publishing target, in exchange for naming. Revisit only if `bloom_server` later grows genuinely server-only concerns that a Flutter app should not see.

## Global Constraints

- **Prerequisite: the streaming-responses work must be committed first.** That plan edits `api_router.dart` and `bloom_response.dart` in *both* packages. Running this plan concurrently would clobber it. Verify with `git status --short` that the tree is clean before starting.
- **`bloom_server` must not gain a Flutter dependency.** Not directly, not transitively. Task 4 enforces this with a test.
- **The public API of both packages must not change.** Consumers import `package:bloom_framework/bloom_server.dart` and `package:bloom_framework/bloom.dart`; those barrels must continue to export exactly the same names. 11 packages depend on `bloom_server` and 5 examples depend on `bloom_framework` — none of them may need an edit.
- **CORRECTED DURING EXECUTION — 29 files import these by relative path.** An earlier claim here said only barrels referenced the duplicated files. That was wrong: it came from a grep for `src/core/logger` and similar, which never matches a relative import like `'../core/logger.dart'`. Deleting the nine files outright produced **209 analyzer errors**.

  The design changed accordingly. The nine paths in `bloom_framework` are **not deleted**; each is replaced by a one-line **re-export shim**:

  ```dart
  export 'package:bloom_server/src/core/logger.dart';
  ```

  This keeps every relative import resolving while leaving exactly one implementation, so there is still nothing that can drift. Rewriting all 29 importers was the alternative and was rejected as pure churn for no benefit.
- Dart SDK `>=3.0.0 <4.0.0`; `test: ^1.25.0`.
- The monorepo uses `dependency_overrides` for in-tree wiring; hosted constraints in `dependencies:` are what ship.

## File Structure

| File | Responsibility |
|---|---|
| `packages/bloom_framework/pubspec.yaml` | Add `bloom_server` to `dependencies` and to `dependency_overrides`. |
| `packages/bloom_framework/lib/bloom_server.dart` | Re-export the server core from `package:bloom_server` instead of local `src/`. |
| `packages/bloom_framework/lib/bloom_core.dart` | Re-export core primitives from `package:bloom_server`. |
| `packages/bloom_framework/lib/bloom.dart` | Update its four core exports to the re-exported source. |
| `packages/bloom_framework/lib/src/server/*.dart` | Replaced by re-export shims (4 files). |
| `packages/bloom_framework/lib/src/core/*.dart`, `src/di/*.dart`, `src/config/env_schema.dart` | Replaced by re-export shims (5 files). |
| `packages/bloom_server/test/no_duplication_test.dart` | New. Regression guard against drift and against a Flutter dependency creeping into `bloom_server`. Lives in `bloom_server`, not `bloom_framework`: the latter's tests run under `flutter_test` and need the Flutter SDK, and a guard protecting a Flutter-free invariant must itself run without Flutter. |

---

### Task 1: Wire `bloom_framework` to depend on `bloom_server`

**Files:**
- Modify: `packages/bloom_framework/pubspec.yaml`

**Interfaces:**
- Consumes: nothing.
- Produces: `package:bloom_server/*` becomes importable from `bloom_framework`.

- [ ] **Step 1: Confirm the tree is clean**

Run: `cd /root/dev/Bloom && git status --short`
Expected: no output. If the streaming-responses work is uncommitted, STOP — that plan must land first.

- [ ] **Step 2: Add the dependency**

In `packages/bloom_framework/pubspec.yaml`, add to the `dependencies:` block, keeping alphabetical position near the other `bloom_*` entries if any exist:

```yaml
  bloom_server: ^0.1.0
```

And in the `dependency_overrides:` block at the bottom of the file, add:

```yaml
  bloom_server:
    path: ../bloom_server
```

- [ ] **Step 3: Resolve dependencies**

Run: `cd packages/bloom_framework && dart pub get`
Expected: resolves successfully.

- [ ] **Step 4: Verify no dependency cycle**

Run: `grep -n "bloom_framework" packages/bloom_server/pubspec.yaml`
Expected: **no output**. `bloom_server` must not depend back on `bloom_framework`.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_framework/pubspec.yaml
git commit -m "build(bloom_framework): depend on bloom_server"
```

---

### Task 2: Replace the duplicated server core with re-exports

**Files:**
- Modify: `packages/bloom_framework/lib/bloom_server.dart`
- Delete: `packages/bloom_framework/lib/src/server/api_router.dart`
- Delete: `packages/bloom_framework/lib/src/server/bloom_middleware.dart`
- Delete: `packages/bloom_framework/lib/src/server/bloom_request.dart`
- Delete: `packages/bloom_framework/lib/src/server/bloom_response.dart`

**Interfaces:**
- Consumes: the `bloom_server` dependency from Task 1.
- Produces: `package:bloom_framework/bloom_server.dart` exports the same names as before, now sourced from `package:bloom_server`, **plus** `rpc_mount` which it previously could not offer.

- [ ] **Step 1: Confirm the four files are byte-identical before deleting**

```bash
cd /root/dev/Bloom
for f in api_router bloom_middleware bloom_request bloom_response; do
  diff -q packages/bloom_server/lib/src/server/$f.dart \
          packages/bloom_framework/lib/src/server/$f.dart \
    && echo "IDENTICAL $f"
done
```
Expected: four `IDENTICAL` lines. If any file differs, STOP and report — a real divergence must be reconciled deliberately, not deleted.

- [ ] **Step 2: Rewrite the barrel**

Replace the entire contents of `packages/bloom_framework/lib/bloom_server.dart` with:

```dart
// lib/bloom_server.dart
//
// The server core lives in `package:bloom_server`, which is Flutter-free so
// that pure-Dart backends can `dart compile exe` without the Flutter SDK.
// This barrel re-exports it so Flutter consumers keep a single import.
//
// The dependency runs one way only: bloom_framework depends on bloom_server,
// never the reverse. Reversing it would drag `package:flutter` into every
// backend. See test/no_duplication_test.dart, which enforces this.
export 'bloom_core.dart';

export 'package:bloom_server/src/server/api_router.dart';
export 'package:bloom_server/src/server/bloom_middleware.dart';
export 'package:bloom_server/src/server/bloom_request.dart';
export 'package:bloom_server/src/server/bloom_response.dart';
export 'package:bloom_server/src/server/rpc_mount.dart';
```

Note this now also exports `rpc_mount`, which the framework copy never had — that is the point, and it fixes the generated SSR server's inability to mount an RPC router.

- [ ] **Step 3: Delete the duplicates**

```bash
git rm packages/bloom_framework/lib/src/server/api_router.dart \
       packages/bloom_framework/lib/src/server/bloom_middleware.dart \
       packages/bloom_framework/lib/src/server/bloom_request.dart \
       packages/bloom_framework/lib/src/server/bloom_response.dart
```

- [ ] **Step 4: Analyze**

Run: `cd packages/bloom_framework && dart analyze`
Expected: `No issues found!`. An `uri_does_not_exist` error means a file outside the barrels was importing a deleted path — report it rather than restoring the file.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_framework/lib/bloom_server.dart
git commit -m "refactor(bloom_framework): re-export server core from bloom_server"
```

---

### Task 3: Replace the duplicated core primitives with re-exports

**Files:**
- Modify: `packages/bloom_framework/lib/bloom_core.dart`
- Modify: `packages/bloom_framework/lib/bloom.dart:6-7,17-18`
- Delete: `packages/bloom_framework/lib/src/core/env.dart`
- Delete: `packages/bloom_framework/lib/src/core/logger.dart`
- Delete: `packages/bloom_framework/lib/src/di/container.dart`
- Delete: `packages/bloom_framework/lib/src/di/scope.dart`
- Delete: `packages/bloom_framework/lib/src/config/env_schema.dart`

**Interfaces:**
- Consumes: the `bloom_server` dependency from Task 1.
- Produces: `bloom_core.dart` and `bloom.dart` export the same names, sourced from `package:bloom_server`.

- [ ] **Step 1: Confirm byte-identity before deleting**

```bash
cd /root/dev/Bloom
for f in src/core/env.dart src/core/logger.dart src/di/container.dart \
         src/di/scope.dart src/config/env_schema.dart; do
  diff -q packages/bloom_server/lib/$f packages/bloom_framework/lib/$f \
    && echo "IDENTICAL $f"
done
```
Expected: five `IDENTICAL` lines.

- [ ] **Step 2: Rewrite `bloom_core.dart`**

Replace the entire contents of `packages/bloom_framework/lib/bloom_core.dart` with:

```dart
// lib/bloom_core.dart
//
// Flutter-independent core primitives (env config, DI container, logger).
// These are defined once in `package:bloom_server` and re-exported here, so
// a Flutter app and a pure-Dart backend share one definition rather than two
// copies that drift.
//
// Never import `bloom.dart` from a server entrypoint — that barrel pulls in
// `package:flutter` (and transitively `dart:ui`), which cannot be resolved
// under a plain `dart run` / `dart compile` process.
library bloom_core;

export 'package:bloom_server/src/core/env.dart';
export 'package:bloom_server/src/core/logger.dart';
export 'package:bloom_server/src/di/container.dart';
export 'package:bloom_server/src/di/scope.dart';
```

- [ ] **Step 3: Update `bloom.dart`**

In `packages/bloom_framework/lib/bloom.dart`, replace line 6-7:

```dart
export 'src/core/env.dart';
export 'src/core/logger.dart';
```

with:

```dart
export 'package:bloom_server/src/core/env.dart';
export 'package:bloom_server/src/core/logger.dart';
```

and replace lines 17-18:

```dart
export 'src/di/container.dart';
export 'src/di/scope.dart';
```

with:

```dart
export 'package:bloom_server/src/di/container.dart';
export 'package:bloom_server/src/di/scope.dart';
```

- [ ] **Step 4: Find any remaining importer of `env_schema.dart`**

Run: `grep -rn "env_schema" packages/bloom_framework/lib --include=*.dart`
Expected: matches only inside `src/config/env_schema.dart` itself. If another file imports it, add the corresponding `package:bloom_server/src/config/env_schema.dart` export to whichever barrel exposed it, and note this in your report.

- [ ] **Step 5: Delete the duplicates**

```bash
git rm packages/bloom_framework/lib/src/core/env.dart \
       packages/bloom_framework/lib/src/core/logger.dart \
       packages/bloom_framework/lib/src/di/container.dart \
       packages/bloom_framework/lib/src/di/scope.dart \
       packages/bloom_framework/lib/src/config/env_schema.dart
```

- [ ] **Step 6: Analyze**

Run: `cd packages/bloom_framework && dart analyze`
Expected: `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add packages/bloom_framework/lib/bloom_core.dart packages/bloom_framework/lib/bloom.dart
git commit -m "refactor(bloom_framework): re-export core primitives from bloom_server"
```

---

### Task 4: Add a regression guard against drift and Flutter creep

**Files:**
- Create: `packages/bloom_framework/test/no_duplication_test.dart`

**Interfaces:**
- Consumes: the finished state of Tasks 1–3.
- Produces: a test that fails if the duplication returns or the dependency direction reverses.

**Rationale:** the two copies stayed identical for their whole life by discipline alone, and discipline is what failed — `rpc_mount.dart` landed in one package only. A test is the only thing that makes this stick.

- [ ] **Step 1: Write the failing test**

Create `packages/bloom_framework/test/no_duplication_test.dart`:

```dart
import 'dart:io';
import 'package:test/test.dart';

/// Resolves a path relative to the bloom_framework package root, regardless of
/// the directory `dart test` was invoked from.
String _repoPath(String relative) {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/pubspec.yaml').readAsStringSync().contains('name: bloom_framework')) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not locate the bloom_framework package root.');
    }
    dir = parent;
  }
  return '${dir.parent.path}/$relative';
}

void main() {
  group('server core is defined exactly once', () {
    const duplicatedPaths = [
      'lib/src/server/api_router.dart',
      'lib/src/server/bloom_middleware.dart',
      'lib/src/server/bloom_request.dart',
      'lib/src/server/bloom_response.dart',
      'lib/src/core/env.dart',
      'lib/src/core/logger.dart',
      'lib/src/di/container.dart',
      'lib/src/di/scope.dart',
      'lib/src/config/env_schema.dart',
    ];

    for (final path in duplicatedPaths) {
      test('bloom_framework does not carry its own copy of $path', () {
        final framework = File(_repoPath('bloom_framework/$path'));
        final server = File(_repoPath('bloom_server/$path'));

        expect(
          server.existsSync(),
          isTrue,
          reason: '$path must exist in bloom_server, its single home.',
        );
        expect(
          framework.existsSync(),
          isFalse,
          reason: 'bloom_framework must re-export $path from package:bloom_server, '
              'not keep a second copy. Two copies drift silently — that is how '
              'rpc_mount.dart ended up in only one package.',
        );
      });
    }
  });

  group('dependency direction', () {
    test('bloom_server does not depend on bloom_framework', () {
      final pubspec = File(_repoPath('bloom_server/pubspec.yaml')).readAsStringSync();
      expect(
        pubspec.contains('bloom_framework'),
        isFalse,
        reason: 'bloom_server must stay Flutter-free. Depending on '
            'bloom_framework would pull in the Flutter SDK and break '
            '`dart compile exe` for every pure-Dart backend.',
      );
    });

    test('bloom_server declares no Flutter dependency', () {
      final pubspec = File(_repoPath('bloom_server/pubspec.yaml')).readAsStringSync();
      expect(
        pubspec.contains('sdk: flutter'),
        isFalse,
        reason: 'bloom_server is deliberately Flutter-free.',
      );
    });

    test('bloom_framework depends on bloom_server', () {
      final pubspec = File(_repoPath('bloom_framework/pubspec.yaml')).readAsStringSync();
      expect(pubspec.contains('bloom_server'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd packages/bloom_framework && dart test test/no_duplication_test.dart`
Expected: PASS (12 tests). If a duplication test fails, Task 2 or 3 left a file behind.

- [ ] **Step 3: Verify bloom_server stayed Flutter-free in the resolved lockfile**

```bash
cd packages/bloom_server && dart pub get && grep -c "flutter" pubspec.lock || echo "0 flutter entries"
```
Expected: `0 flutter entries`, or a count of 0. A non-zero count means Flutter entered transitively — report it.

- [ ] **Step 4: Run every affected suite**

```bash
cd packages/bloom_framework && dart analyze && dart test
cd ../bloom_server && dart analyze && dart test
cd ../bloom_cli && dart analyze && dart test -j 2
```
Expected: all pass. Use `-j 2` for `bloom_cli`; at `-j 4` its Phase 12 integration test intermittently exceeds a 30s timeout under load.

- [ ] **Step 5: Verify dependent packages still resolve**

```bash
cd /root/dev/Bloom
for pkg in bloom_auth_server bloom_admin bloom_i18n bloom_security bloom_mail \
           bloom_rest bloom_realtime bloom_cache bloom_storage bloom_errors bloom_validate; do
  (cd packages/$pkg && dart pub get >/dev/null 2>&1 && dart analyze 2>&1 | tail -1 | sed "s|^|$pkg: |")
done
```
Expected: `No issues found!` for all eleven. These depend on `bloom_server`, whose API did not change, so any failure is a real surprise worth reporting.

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_framework/test/no_duplication_test.dart
git commit -m "test(bloom_framework): guard against server core duplication"
```

---

## Self-Review

**1. Spec coverage.** Background names three harms. "Change must be applied twice" is removed by Tasks 2–3. "Nothing detects drift" is addressed by Task 4. "`rpc_mount` missing from the framework barrel" is fixed in Task 2 Step 2, which adds the export the framework copy never had.

**2. Placeholder scan.** No TBDs. Every code step carries literal content, including the full replacement text of all three barrels and the complete test file.

**3. Type consistency.** No new types are introduced. Every export path in Tasks 2 and 3 corresponds to a file confirmed to exist in `bloom_server` by the `IDENTICAL` listing in Background. `_repoPath` is defined once in Task 4 and used only there.

## Risks

- **`package:bloom_server/src/...` reaches into another package's `src/`.** Dart permits it, but it is conventionally private and `package:` lint rules sometimes flag it. If `dart analyze` objects, the fix is to add a public barrel to `bloom_server` (for example `lib/server_core.dart`) exporting those four files, and have `bloom_framework` export that instead. Prefer this if the analyzer complains — do not suppress the lint.
- **Version skew after publishing.** Once `bloom_framework` depends on `bloom_server: ^0.1.0`, a breaking change to the server core requires a coordinated release. This is a genuine new coupling, and it is the price of removing the duplication.
- **The prerequisite is real.** Running this before the streaming work is committed will destroy it. Task 1 Step 1 exists to catch that.

## Out of Scope

- Extracting a separate `bloom_core` package (rejected above, with reasoning).
- The remaining 78 `bloom_framework` files that have no `bloom_server` counterpart — they are genuinely Flutter-side and stay where they are.
- Streaming request bodies, SSE, and the headless-Chromium SSR architecture, all tracked separately.
