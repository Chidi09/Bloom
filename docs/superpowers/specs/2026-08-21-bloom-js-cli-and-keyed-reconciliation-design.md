# Bloom JS CLI & Keyed DOM Reconciliation Design Specification

## 1. Goal
1. Add `bloom js` subcommands (`bloom js dev`, `bloom js build`, `bloom js vendor`) to `packages/bloom_cli`.
2. Implement keyed DOM list reconciliation in `packages/bloom_js_native/lib/src/mount.dart` to preserve DOM identity, focus, and animation states when lists reorder or splice.

## 2. Keyed DOM Reconciliation Algorithm (`mount.dart`)
- When `keyFn` is present in `ForEachNode<T>`:
  - Instead of `container.textContent = ''`, maintain an active map `_activeKeys: Map<String, _KeyedEntry>`.
  - `_KeyedEntry` holds `web.Node node`, `_Region region`, and `T item`.
  - For each new item:
    - If key exists: reuse `entry.node`, update item.
    - If key does not exist: mount child into fresh `_Region`, create `entry`.
  - Keys absent from the new list have their `_Region.disposeAll()` called and their DOM node removed.
  - Re-order DOM nodes in `container` using `container.insertBefore()` to match the exact new list order.

## 3. `bloom js` CLI Suite (`packages/bloom_cli`)
- Registered as top-level `JsCommand` in `bloom_cli/bin/bloom.dart`:
  - `bloom js dev`:
    - Checks/runs `NpmVendorAssembler.assemble()`.
    - Serves `web/` or `example/` via `HttpServer` with SSE live-reload.
    - Watches `.dart` files and recompiles with `dart compile js`.
  - `bloom js build`:
    - Compiles `lib/main.dart` or `example/main.dart` with `dart compile js -O4`.
    - Flag `--analyze`: Computes raw byte sizes, gzip estimated sizes, and formats a clean terminal budget table.
  - `bloom js vendor`:
    - Invokes `NpmVendorAssembler.assemble(preferBun: true)`.

## 4. Verification & Quality Gates
- 0 analyzer errors and 0 warnings.
- Comprehensive unit tests in `bloom_cli` and `bloom_js_native`.
