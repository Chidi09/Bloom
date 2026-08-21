# REACTIVITY — Bloom JS Native

Reactivity is `package:signals` (the same `signals: ^5.5.0` used by `bloom_framework`). Dart owns it; the browser just gets told what to patch.

## Primitives (re-exported)

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);               // Signal<int>
final doubled = computed(() => count.value * 2); // Computed<int>
effect(() => print(count.value));      // runs now, re-runs on count change
batch(() { count.value++; count.value++; }); // one notification cycle
```

## Live — the `{expr}` of JSX

```dart
Live(() => P(text: 'Count: ${count.value}'))
```

- The closure is re-evaluated **inside a `signal effect`** on mount.
- Only the DOM region owned by that `Live` is patched (v0: container cleared and rebuilt; future: granular text-node patch).
- Nest arbitrarily — `Live` inside `Li` inside `ForEach` is fine.

## Show — conditional

```dart
Show(() => count.value > 9,
  child: P(text: 'Double digits!'),
  fallback: P(text: 'Keep clicking'),
)
```

- `when` is a `bool Function()` called inside an effect (browser) or once (SSR).
- Omit `fallback` for “render or nothing”.

## ForEach — list

```dart
ForEach(() => todos.value, (t) => Li(children: [Text(t.title)]))
```

- `items` is `List<T> Function()` — typically `() => todos.value`.
- v0 rebuilds the whole list on any change (simple + correct). Keyed reconciliation (using `key:`) lands in M4 once profiled on big lists.

```dart
ForEach(() => users.value, (u) => Li(text: u.name), key: (u) => u.id)
```

## Disposal rules

- `mount()` returns `BloomMountHandle`. Every `effect` registered while mounting is stored.
- `handle.unmount()` (alias `dispose()`) disposes all effects and clears the root. No leaks.
- If you create effects outside the tree (e.g. global store logging), dispose them yourself or tie their lifetime to a mount handle via `handle`’s disposer list.

## Common pitfalls

1. **Reading signals outside Live/Show/ForEach/computed/effect** — no tracking, no re-render. Move the read inside.
2. **Mutating a list in place without reassigning `.value`** — signals are reference-checked. Either `todos.value = [...todos.value, newItem]` or use mutable signal helpers if provided.
3. **Expensive work in a Live builder** — it runs on every dependency change. Extract to `computed()` if needed.
4. **Forgetting `unmount()` on hot reload / SPA navigation** — dispose the previous handle before re-mounting.

## De-Fluttered Watch

Ported concept from `bloom_framework/lib/src/state/watch.dart` (`SignalBuilder`/`Watch`) but without Flutter `BuildContext`. Bloom JS Native’s equivalent is `Live` — a closure, not a widget, because there is no widget tree.

## Testing reactivity

```dart
final c = signal(0);
final node = Live(() => Text('${c.value}'));
expect(renderToHtml(node), '0');
c.value = 1;
expect(renderToHtml(node), '1'); // SSR re-evaluates fresh each render
// Browser: effect patches DOM automatically — test with dart test -p chrome
```
