# Bloom JS CLI & Keyed Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement keyed DOM list reconciliation in `packages/bloom_js_native/lib/src/mount.dart` and add the full `bloom js` command suite (`bloom js dev`, `bloom js build --analyze`, `bloom js vendor`) to `packages/bloom_cli`.

**Architecture:** Augment `_bindReactiveRegion` in `mount.dart` with a keyed reconciliation branch that diffs by key and patches the DOM in-place using `insertBefore`; create `JsCommand` with `JsDevCommand`, `JsBuildCommand`, and `JsVendorCommand` in `bloom_cli`.

**Tech Stack:** Dart 3.4+, `package:web`, `bloom_cli`, `bloom_js_native`, `archive` / `gzip`.

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-cli-and-keyed-reconciliation-design.md`

## Global Constraints
- Zero errors and zero warnings across `dart analyze`.
- All tests must pass cleanly via `dart test`.
- Keyed reconciliation must properly dispose old child effects on item removal.

---

### Task 1: Keyed DOM List Reconciliation in `mount.dart`

**Files:**
- Modify: `packages/bloom_js_native/lib/src/mount.dart`
- Modify: `packages/bloom_js_native/lib/src/framework.dart`
- Test: `packages/bloom_js_native/test/framework_test.dart`

**Interfaces:**
- Consumes: `ForEachNode<T>`, `_Region`, `web.Node`
- Produces: In-place DOM reconciliation without tearing down entire container

- [ ] **Step 1: Write unit test for ForEachNode keyFn preservation**

In `packages/bloom_js_native/test/framework_test.dart`:
```dart
test('ForEachNode keyFn extracts key string correctly', () {
  final items = signal([{'id': 'a', 'text': 'Apple'}, {'id': 'b', 'text': 'Banana'}]);
  final forEach = ForEach<Map<String, String>>(
    () => items.value,
    (m) => Li(text: m['text']!),
    key: (m) => m['id']!,
  );
  expect(forEach.keyFn, isNotNull);
  expect(forEach.keyFn!(items.value[0]), 'a');
  expect(forEach.keyFn!(items.value[1]), 'b');
});
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd packages/bloom_js_native && dart test test/framework_test.dart`

- [ ] **Step 3: Implement Keyed Reconciliation in `mount.dart`**

In `packages/bloom_js_native/lib/src/mount.dart`, implement `_bindKeyedForEach` for `ForEachNode` when `node.keyFn != null`, tracking active entries and moving/reusing DOM nodes.

- [ ] **Step 4: Run tests to verify clean compilation**

Run: `cd packages/bloom_js_native && dart test`
Expected: 43+ PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/
git commit -m "feat(bloom_js_native): implement keyed DOM list reconciliation"
```

---

### Task 2: `bloom js` CLI Command Suite in `packages/bloom_cli`

**Files:**
- Create: `packages/bloom_cli/lib/src/commands/js_command.dart`
- Modify: `packages/bloom_cli/bin/bloom.dart`
- Test: `packages/bloom_cli/test/bloom_js_command_test.dart`

**Interfaces:**
- Consumes: `BloomProject`, `NpmVendorAssembler`
- Produces: `bloom js dev`, `bloom js build`, `bloom js vendor`

- [ ] **Step 1: Write test for JsCommand registration and flag parsing**

In `packages/bloom_cli/test/bloom_js_command_test.dart`:
```dart
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/js_command.dart';
import 'package:test/test.dart';

void main() {
  group('JsCommand', () {
    test('registers dev, build, and vendor subcommands', () {
      final cmd = JsCommand();
      expect(cmd.name, 'js');
      expect(cmd.subcommands.keys, containsAll(['dev', 'build', 'vendor']));
    });
  });
}
```

- [ ] **Step 2: Implement JsCommand, JsDevCommand, JsBuildCommand, and JsVendorCommand**

In `packages/bloom_cli/lib/src/commands/js_command.dart`, implement:
- `JsDevCommand`: starts HTTP static server, sets up file watcher, runs `dart compile js`, sends live-reload SSE.
- `JsBuildCommand`: compiles with `dart compile js -O4`, with `--analyze` flag measuring byte budgets.
- `JsVendorCommand`: runs `NpmVendorAssembler.assemble(preferBun: true)`.

- [ ] **Step 3: Register `JsCommand` in `packages/bloom_cli/bin/bloom.dart`**

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/bloom_cli && dart test test/bloom_js_command_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_cli/
git commit -m "feat(bloom_cli): add bloom js dev, build, and vendor CLI commands"
```

---

### Task 3: Full Monorepo Quality Gate & Verification

**Files:**
- Verify: `packages/bloom_js_native`
- Verify: `packages/bloom_cli`

- [ ] **Step 1: Run dart analyze on all packages**

Run: `dart analyze packages/bloom_js_native packages/bloom_seo packages/bloom_framework packages/bloom_cli examples/bloom_todo/apps/web`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Run all tests**

Run: `cd packages/bloom_js_native && dart test`
Run: `cd packages/bloom_cli && dart test test/bloom_js_command_test.dart`
Expected: All tests pass.

- [ ] **Step 3: Final Commit**

```bash
git add .
git commit -m "chore: verify zero analysis warnings and green test suite for bloom js CLI and keyed reconciliation"
```
