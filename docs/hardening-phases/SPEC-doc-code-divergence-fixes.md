# SPEC: Doc/Code Divergence & Correctness Fixes — `bloom_framework` + `bloom_cli`

**Status:** Proposed
**Scope:** `packages/bloom_framework`, `packages/bloom_cli`
**Baseline:** `dart analyze` clean on both packages; `flutter test` 102/102 pass (framework); `dart test` 62/62 pass (CLI). Every issue below is invisible to the current suites.

---

## Severity summary

| # | Area | Issue | Severity |
| :-- | :-- | :-- | :-- |
| B1 | `data/cache.dart` | `invalidateQueries` is a no-op for queries with no cache entry | **High** |
| B2 | `data/cache.dart` | GC closes invalidation controllers still held by live queries | **High** |
| B3 | `data/cache.dart` | `normalizeKey` is order-sensitive for Map segments, contradicting docs | **High** |
| B4 | `cli/native/*_prebuild.dart` | Documented plugins get no prebuild transformations | **High** |
| B5 | `cli/commands/add_command.dart` | No plugin-name validation/normalization | **Medium** |
| B6 | `state/controller.dart` | `createSignal`/`createComputed`/`dispose()` documented but absent | **Medium** |
| B7 | `di/container.dart` | Factory arity mismatch: docs use `(c) => ...`, code uses `() => ...` | **Medium** |
| B8 | `data/query.dart` | `BloomData.query(...)` entry point absent; param names differ | **Medium** |
| B9 | `data/query.dart` | `isLoading`/`isError` are `bool`, documented as `ReadonlySignal<bool>` | **Medium** |
| B10 | `state/watch.dart` | `SignalBuilder` builder arity mismatch with docs | **Low** |
| B11 | `data/cache.dart` | `clearCache()` documented, actual name is `clear()` | **Low** |
| B12 | `di/container.dart` | `dumpContainer()` returns a different shape than documented | **Low** |
| B13 | `core/boot.dart` | Boot doc lists 10 steps in wrong order; code has 11 | **Low** |
| B14 | `core/boot.dart` | `Bloom.reset()` is async; docs call it unawaited in `setUp` | **Low** |
| B15 | `cli/commands/build_command.dart` | `--flavor` forwarded to targets that reject it | **Low** |

---

## B1 — `invalidateQueries` silently does nothing for uncached queries

**File:** `packages/bloom_framework/lib/src/data/cache.dart:71-87`

`invalidateQueries` iterates **only `_cache`** to decide which invalidation controllers to signal. A `BloomQuery` writes its cache entry only after a *successful* fetch (`query.dart:114`). Therefore any query that has never succeeded — still loading, or in `QueryStatus.error` — has no `_cache` entry, so its controller is never signalled.

**Failure scenario:** a query's fetch fails (offline). User taps "Retry", which calls `userQuery.invalidate()`. `invalidate()` delegates to `BloomData.invalidateQueries(key)` (`query.dart:86-88`), which finds no matching cache entry and returns without emitting. No refetch occurs; the UI stays on the error state forever. `docs/data/queries.md:75-79` documents `invalidate()` as forcing a refetch.

**Fix:** signal the union of matching cache entries *and* matching registered invalidation controllers.

```dart
static void invalidateQueries(List<dynamic> keyPrefix) {
  final matching = <String>{};
  for (final entry in _cache.values) {
    if (matchesKey(entry.key, keyPrefix)) {
      entry.isStale = true;
      matching.add(normalizeKey(entry.key));
    }
  }
  // Also reach queries that have never cached a successful result.
  for (final keyStr in _invalidationControllers.keys) {
    if (_matchesNormalizedPrefix(keyStr, keyPrefix)) matching.add(keyStr);
  }
  for (final keyStr in matching) {
    _invalidationControllers[keyStr]?.add(null);
  }
}
```

Add a private `_matchesNormalizedPrefix(String keyStr, List<dynamic> prefix)` comparing `keyStr` against `normalizeKey(prefix)` on `:` segment boundaries (guard against `users` matching `usersettings` by requiring an exact match or a `:` at the boundary).

**Regression test:** construct a query whose fetcher throws, await the error state, register a fetcher that succeeds, call `invalidate()`, and assert the query reaches `QueryStatus.success`.

---

## B2 — Garbage collection closes controllers held by live queries

**File:** `packages/bloom_framework/lib/src/data/cache.dart:157-172`

`garbageCollect()` evicts expired entries and calls `_invalidationControllers.remove(k)?.close()`. A mounted `BloomQuery` subscribed via `onInvalidated` (`query.dart:60`) has its stream closed underneath it. It is never resubscribed, so that query is permanently deaf to all future invalidations — a silent, time-delayed failure that only manifests after `cacheTime` elapses (GC runs every 5 minutes by default).

This also contradicts `docs/data/cache_and_garbage_collection.md:38`, which specifies eviction only for entries "with zero active UI listeners". No listener count is tracked anywhere.

**Fix (two parts):**

1. Track subscribers. Add `static final Map<String, int> _listenerCounts` incremented in `onInvalidated` and decremented from `BloomQuery.dispose()` (add a `BloomData.releaseListener(key)` call there). In `garbageCollect()`, skip eviction when `(_listenerCounts[k] ?? 0) > 0`, matching the documented contract.
2. Never close a controller that still has listeners. Guard the `close()` with the same check; prefer leaving the controller in place and only removing the `_cache` entry.

**Regression test:** create a query with `cacheTime: Duration.zero`, run `BloomData.garbageCollect()`, then call `invalidate()` and assert a refetch still occurs.

---

## B3 — `normalizeKey` is order-sensitive for Map segments

**File:** `packages/bloom_framework/lib/src/data/cache.dart:54-56`

`normalizeKey` is `key.map((e) => e.toString()).join(':')`. `docs/data/cache_and_garbage_collection.md:15` claims normalization ensures "identical objects with different property orders map to the exact same cache slot". `Map.toString()` preserves insertion order, so:

```dart
normalizeKey(['users', {'status': 'active', 'page': 1}]) // users:{status: active, page: 1}
normalizeKey(['users', {'page': 1, 'status': 'active'}]) // users:{page: 1, status: active}
```

These are different cache slots. Two call sites requesting semantically identical data double-fetch, double-cache, and invalidate independently.

**Fix:** canonicalize recursively before stringifying — sort `Map` entries by key, recurse into nested `Map`/`Iterable` values, and leave scalars as-is.

```dart
static String normalizeKey(List<dynamic> key) => key.map(_canonical).join(':');

static String _canonical(dynamic e) {
  if (e is Map) {
    final entries = e.entries.map((kv) => '${kv.key}: ${_canonical(kv.value)}').toList()..sort();
    return '{${entries.join(', ')}}';
  }
  if (e is Iterable) return '[${e.map(_canonical).join(', ')}]';
  return e.toString();
}
```

Note `matchesKey` (`cache.dart:59-68`) compares segments with `.toString()` and must use `_canonical` too, or prefix matching diverges from slot naming.

**Regression test:** assert the two key orderings above produce an identical normalized key and share one cache entry.

---

## B4 — Documented plugins receive no prebuild transformations

**Files:** `packages/bloom_cli/lib/src/native/android_prebuild.dart:38-49`, `ios_prebuild.dart:37`

`docs/native/plugins.md:9-15` promises specific managed transformations per plugin. The prebuild engines only branch on `'camera'`, `'notifications'`, and `'location'`. Consequences:

- **`background-tasks`** — `WAKE_LOCK` and background execution policies are documented but never injected.
- **`secure-storage`** — Keychain access group and Android backup rules are documented but never injected.
- **`location`** — handled in code but absent from the documented plugin table.
- Hyphenated names from `docs/cli/commands.md:17-21` (`secure-storage`, `background-tasks`) match none of the underscore-free string literals, so even the implemented branches are unreachable via the documented CLI syntax.

**Fix:** introduce one shared plugin descriptor table in the CLI (e.g. `lib/src/native/plugin_catalog.dart`) keyed by canonical plugin id, holding `{androidPermissions, iosUsageDescriptions, manifestPatches}`. Both prebuild engines and `add`/`remove` read from it. Populate entries for all five documented plugins plus `location`, and reconcile the doc table with the catalog so the two cannot drift again.

**Regression test:** run prebuild against a fixture project declaring `background-tasks` and assert `WAKE_LOCK` lands in the generated `AndroidManifest.xml`.

---

## B5 — `bloom add` accepts any string as a plugin name

**File:** `packages/bloom_cli/lib/src/commands/add_command.dart:22-52`

The command lowercases `rest.first` and writes it straight into `bloom.yaml`'s `plugins` list, then runs prebuild. There is no membership check against the documented plugin set, and no hyphen/underscore normalization. `bloom add camrea` exits 0, writes a bogus entry, and produces no transformations — the user gets a success message and a silently broken build. This is inconsistent with `create-module`, which validates its name and exits 1 on invalid input.

**Fix:** resolve the argument against the B4 catalog, normalizing `-` and `_` to a canonical id. On no match, print the supported list and return exit code 1. Apply the identical normalization in `remove_command.dart` so add/remove round-trip. Update the `add` error hint to use the documented hyphenated spelling.

**Regression test:** assert `bloom add camrea` exits 1 and leaves `bloom.yaml` unmodified; assert `bloom add secure-storage` and `bloom add secure_storage` both write the same canonical entry.

---

## B6 — `BloomController` is missing its documented state helpers

**File:** `packages/bloom_framework/lib/src/state/controller.dart`

`docs/runtime/signals_and_controllers.md:102-112,154-155` presents `createSignal<T>()` and `createComputed<T>()` as the canonical way to declare controller state, and the lifecycle table (line 157) refers to `dispose()`. None of the three exist — the class only has `addEffect`, `autoDispose`, `onInit`, and `onDispose`. The documented `TodoController` example does not compile, and there is no public method to trigger teardown (`onDispose` is the `@mustCallSuper` hook, not the entry point).

**Fix:** add to `BloomController`:

```dart
Signal<T> createSignal<T>(T initial, {String? debugLabel}) {
  final s = signal<T>(initial, debugLabel: debugLabel ?? '$runtimeType.signal');
  autoDispose(() => s.dispose());
  return s;
}

Computed<T> createComputed<T>(T Function() compute, {String? debugLabel}) {
  final c = computed<T>(compute, debugLabel: debugLabel ?? '$runtimeType.computed');
  autoDispose(() => c.dispose());
  return c;
}

void dispose() => onDispose();
```

`signals.dart` must re-export `Signal`/`Computed` (it already does). Keep `onDispose` as the overridable hook so existing subclasses are unaffected.

**Regression test:** a controller declaring `createSignal`/`createComputed`, then `dispose()`, asserting `isDisposed` and that registered effects stopped firing.

---

## B7 — DI factory arity mismatch

**Files:** `packages/bloom_framework/lib/src/di/container.dart:4`, docs `runtime/dependency_injection.md:14,20`, `runtime/boot_lifecycle.md:69-72`

`FactoryFunc<T> = T Function()` takes no arguments, but *every* documented registration passes a container: `container.provideSingleton<ApiService>((c) => ApiService())`. Both the DI guide and the boot guide use this form, so it is the intended public API, and every copy-pasted example fails to compile.

**Fix:** change the typedef to `typedef FactoryFunc<T> = T Function(BloomContainer container);` and thread the owning container through `_Binding.resolve(BloomContainer c)`. This is the more useful signature regardless — it lets a factory resolve its own dependencies from the correct scope rather than reaching for the global container. Update the eager-singleton path in `_Binding.singleton` (which currently calls `factory!()` during construction, before a container reference exists) to defer instantiation to a post-registration hook in `provideSingleton`.

Because this is a source-breaking change to a public API, land it with a `CHANGELOG` entry and update in-repo call sites (`boot.dart:181` uses `provideValue`, which is unaffected).

**Regression test:** register a factory that resolves a second dependency from its `container` argument and assert correct scope resolution through a parent/child pair.

---

## B8 — `BloomData.query(...)` does not exist

**File:** `packages/bloom_framework/lib/src/data/query.dart:155`, docs `data/queries.md:14-23`

Docs open with `BloomData.query<User>(queryKey: ..., queryFn: ..., retryCount: 3)`. There is no static `query` on `BloomData`. The real API is a top-level `query<T>({key, fetch, staleTime, cacheTime, enabled, retry, retryDelay})` / the `BloomQuery<T>` constructor. Three of the documented parameter names (`queryKey`, `queryFn`, `retryCount`) do not exist.

**Fix:** prefer changing the docs to the real top-level `query<T>(key:, fetch:, retry:)` form — it is already exported from `bloom.dart` and is the idiomatic surface. If the `BloomData.query` spelling is wanted for TanStack familiarity, add it as a thin static forwarder, but do **not** introduce the alternate parameter names; pick one vocabulary and apply it across `queries.md`, `mutations.md`, and `repositories.md`.

---

## B9 — Query status accessors are not signals

**File:** `packages/bloom_framework/lib/src/data/query.dart:69-78`

`data`, `status`, `error`, `isFetching`, `isStale` are `ReadonlySignal`s. But `isLoading`, `isSuccess`, `isError`, and `hasData` are **plain `bool` getters** derived from `_status.value`. `docs/data/queries.md:35-39` types `isLoading` and `isError` as `ReadonlySignal<bool>`, and the `Watch` example at line 48 reads `userQuery.isLoading.value` — which does not compile.

Reactivity itself is fine (the getters read `_status.value` inside the `Watch` closure, so tracking works). This is purely an API-shape divergence.

**Fix:** the plain-bool form is the better ergonomic; correct the docs — retype the table rows as `bool` and rewrite the example to `userQuery.isLoading` / `userQuery.isError`. Also fix the status enum name: docs say `BloomQueryStatus`, the code declares `QueryStatus`. Rename in docs, not code.

---

## B10 — `SignalBuilder` builder arity

**File:** `packages/bloom_framework/lib/src/state/watch.dart:8`

Bloom's own `SignalBuilder` takes `Widget Function(BuildContext, T)`. `docs/runtime/signals_and_controllers.md:76` shows a three-argument `(context, value, child)` builder (the `ValueListenableBuilder` shape). There is no `child` parameter and no `child` field. Docs do not compile.

**Fix:** correct the doc to the two-argument form. Adding an optional `child` passthrough is a reasonable optional enhancement but is not required for correctness.

---

## B11 — `BloomData.clearCache()` does not exist

**File:** `packages/bloom_framework/lib/src/data/cache.dart:234`, docs `data/cache_and_garbage_collection.md:64`

The method is `clear()`. Rename in docs, or add a `clearCache()` alias. Prefer the doc fix — note `ext.bloom.clearCache` in `devtools_service.dart:38` is a VM service extension name and is unrelated.

---

## B12 — `dumpContainer()` output shape

**File:** `packages/bloom_framework/lib/src/di/container.dart:120-139`, docs `runtime/dependency_injection.md:99-103`

Docs show a flat `{"DatabaseService": "singleton (instantiated: true)"}` map. The code returns `{bindingsCount, bindings: [...], overridesCount, overrides, hasParent}`. The real shape is strictly more useful and is consumed by DevTools; **fix the docs**, not the code.

---

## B13 — Boot sequence documented incorrectly

**File:** `packages/bloom_framework/lib/src/core/boot.dart:115-253`, docs `runtime/boot_lifecycle.md:38-49`

Docs list 10 steps with flavor discovery at #2 and config load at #3. The code loads `BloomConfig` **first** (step 2, line 119) and resolves the flavor **second** (step 3, line 131) — necessarily so, since flavor-specific env-file resolution reads `_config.flavors`. The code also has an 11th step, observability/telemetry init (line 202), absent from the doc.

**Fix:** rewrite the doc block to the real 11-step order. Also document the `envContent`, `configYaml`, `observability`, and `environmentSchema` parameters of `boot()`, none of which appear in the doc.

---

## B14 — `Bloom.reset()` is async but documented as fire-and-forget

**File:** `packages/bloom_framework/lib/src/core/boot.dart:261`, docs `runtime/boot_lifecycle.md:97-99`

`reset()` returns `Future<void>` and awaits `BloomObservability.reset()`. The doc shows `setUp(() { Bloom.reset(); })` — unawaited, so observability teardown races the next test and leaks state between tests, exactly the failure mode the section claims to prevent.

**Fix:** doc becomes `setUp(() async { await Bloom.reset(); });`.

---

## B15 — `bloom build` forwards `--flavor` to targets that reject it

**File:** `packages/bloom_cli/lib/src/commands/build_command.dart:129-132`

`--flavor` is appended unconditionally for every target. `flutter build web` (and the desktop targets) do not accept `--flavor` and fail with a usage error. `docs/cli/commands.md:52` documents `--flavor` as a general option for all four documented targets including `web`.

**Fix:** keep the `--dart-define=BLOOM_FLAVOR=$flavor` for all targets (that is Bloom's own mechanism and is universally valid), but only append the `--flavor` pair for targets that support it (`apk`, `appbundle`, `ipa`, `ios`, `android`). Emit a note for other targets explaining that the flavor is applied via dart-define only.

---

## Suggested landing order

1. **B1, B2, B3** — data-layer correctness; independent of each other, all test-coverable, highest user impact.
2. **B4, B5** — CLI plugin catalog; B5 depends on the catalog introduced in B4.
3. **B6, B7** — framework public API additions; B7 is source-breaking and needs a CHANGELOG entry.
4. **B8–B15** — documentation reconciliation, plus the small B15 CLI guard.

Every code fix above ships with the regression test named in its section; the current suites pass with all fifteen defects present, which is the underlying gap to close.
