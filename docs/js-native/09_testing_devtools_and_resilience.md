# 09 — Testing, DevTools, Lazy Loading & Resilience

This doc covers the parts of Bloom JS Native that round out the framework's
day-to-day developer experience: `useReducer`-style state, component
testing, DevTools inspection, a dev error overlay, code-splitting via
`lazy()`, and data-loader routes with automatic revalidation.

---

## 1. `useReducer` — `BloomReducer`

For state whose next value depends on a fixed set of named transitions
(rather than ad-hoc `signal.value = ...` writes), `useReducer` mirrors
React's hook of the same name, backed by the same `signals` package as the
rest of the framework's reactivity:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

enum CounterAction { increment, decrement, reset }

int counterReducer(int state, CounterAction action) => switch (action) {
      CounterAction.increment => state + 1,
      CounterAction.decrement => state - 1,
      CounterAction.reset => 0,
    };

final counter = useReducer(counterReducer, 0);

counter.dispatch(CounterAction.increment);
print(counter.state.value); // 1

// Reactive like any other signal — use inside Live()/effect() as usual:
Live(() => P(text: 'Count: ${counter.state.value}'));
```

- `counter.state` is a `ReadonlySignal<S>` — read it, don't write it directly;
  all transitions go through `dispatch`.
- `counter.history` is a read-only, oldest-first log of dispatched actions —
  primarily a debugging aid (DevTools §3 can surface it), not required for
  normal use.
- `reducerFn` must stay pure (no side effects) — the same contract React
  places on a reducer function.

---

## 2. Component Testing — `bloom_test`

`bloom_test` is Bloom's Testing-Library equivalent: it renders a descriptor
tree directly (no browser, no DOM) and exposes query/interaction helpers
that operate on the `BloomNode` tree itself.

```dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  test('button click increments the counter', () {
    final count = signal(0);
    final tree = Div(children: [
      Live(() => P(attrs: {'data-testid': 'count'}, text: '${count.value}')),
      Button(text: '+1', onClick: (_) => count.value++, attrs: {'data-testid': 'inc'}),
    ]);

    final r = renderForTest(tree);
    expect(r.getByTestId('count').text, '0');

    fireEvent.click(r.getByTestId('inc'));
    expect(r.getByTestId('count').text, '1');
  });
}
```

### Queries

- `getByTestId(id)` / `queryByTestId(id)` — via `data-testid`. `getBy*` throws
  if not found; `queryBy*` returns `null`.
- `getByText(text)` / `queryByText(text)` — exact text-content match.
- `getByTag(tag)` / `queryByTag(tag)` — by HTML tag name.
- `r.toHtml()` — renders the current tree to an HTML string (via the same
  engine as `renderToHtml`) for snapshot-style assertions.

### `fireEvent`

`fireEvent.click(node)`, `.input(node, value)`, `.change(node, value)`,
`.submit(node)`, and a generic `.custom(node, type, {...})` dispatch a
synthetic `BloomEvent` straight to the matched node's handler — no real DOM
event loop involved, so these run at VM-test speed.

Because none of this touches `package:web`, `bloom_test` runs on the plain
Dart VM (`dart test`) — no headless browser required, matching how the rest
of the framework's descriptor-tree logic is tested.

---

## 3. DevTools — `BloomJsDevTools`

`BloomJsDevTools` is a lightweight, dependency-free inspector — think React
DevTools' component-tree/profiler panels, minus the browser extension.

```dart
// Serialize a tree for inspection (JSON-able Map):
final snapshot = BloomJsDevTools.snapshotTree(app);

// Bounded ring-buffer event log (default cap: 200 entries):
BloomJsDevTools.notify('mount-error', {'error': 'boom'});
final events = BloomJsDevTools.eventLog; // List<BloomDevToolsEvent>
BloomJsDevTools.clearEventLog();

// Live count of active reactive regions (Live/Show/ForEach/Suspense/etc.):
print(BloomJsDevTools.activeRegionCount);
```

`snapshotTree` walks `ElNode`/`TextNode`/`FragmentNode` into a plain,
JSON-serializable `Map` (tag, text, attrs, children); other node types get a
generic fallback entry naming their runtime type. `mount.dart` already calls
`BloomJsDevTools.notify('mount-error', ...)` internally whenever a mount
throws, so the event log captures runtime failures even when the dev error
overlay (below) is disabled.

---

## 4. Dev Error Overlay

`renderDevErrorOverlay(error, stackTrace, {componentName, sourceHint})`
returns a full-screen, inline-styled HTML fragment — a Vite/CRA-style
"red screen" — for surfacing an uncaught mount-time error during
development. `renderDevErrorOverlayJson(...)` returns the same information
as a JSON payload instead, for tooling that wants structured data rather
than pre-rendered HTML.

It's wired directly into `mountToElement`'s error path:

```dart
import 'package:bloom_js_native/browser.dart';

void main() {
  bloomDevErrorOverlayEnabled = true; // flip on in a dev bootstrap only
  mount(App(), '#app');
}
```

With the flag on, an error thrown while mounting clears the root and injects
the overlay instead of leaving a half-mounted tree or an uncaught exception;
with it off (the default — never enable this in a production build), the
error propagates normally after disposing whatever effects the failed mount
had already registered, and `BloomJsDevTools.notify('mount-error', ...)`
still fires either way.

---

## 5. Code-Splitting — `lazy()`

`lazy(loader, {required fallback})` is React.lazy's equivalent, built as
pure sugar over `Suspense`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final HeavyChart = lazy(
  () async {
    // Pairs with Dart's `deferred as` for a real separate JS chunk:
    final lib = await import_heavy_chart_lib();
    return lib.ChartComponent();
  },
  fallback: P(text: 'Loading chart…'),
);
```

The loader `Future` is cached (`BloomLazyComponent`) — calling the component
multiple times only invokes the loader once, matching React.lazy's
single-fetch guarantee. Because it's just `Suspense` underneath, `lazy()`
gets the same fallback rendering on SSR and the same progressive-streaming
treatment from `renderToStreamWithSuspense` (§05.2) that any other `Suspense`
boundary does — including when nested arbitrarily deep in the tree.

---

## 6. Route Data Loaders — `BloomRoute.loader`

`BloomRoute` accepts three optional fields that give a route React Router's
`loader` ergonomics, built entirely as `Suspense` sugar (no new rendering
machinery):

```dart
BloomRoute(
  path: '/todos/:id',
  loader: (params) => api.fetchTodo(params['id']!),
  dataBuilder: (params, todo) => TodoDetail(todo: todo),
  loadingFallback: () => P(text: 'Loading todo…'),
)
```

When `loader` is present, the matched route is automatically wrapped in a
`Suspense`: `loader(params)` becomes the `resource`, `dataBuilder(params,
data)` (or, if omitted, the route's plain `builder(params)`) becomes the
`builder`, and `loadingFallback()` becomes the `fallback`. A route with no
`loader` builds synchronously exactly as before — this is opt-in per route.

**Revalidation on mutation** (React Router's `action` + revalidation loop)
doesn't need any router-level changes — it composes two primitives that
already exist independently:

```dart
// Inside the loaded page component:
final todoQuery = BloomQuery<Todo>(
  key: ['todo', todoId],
  fetch: () => api.fetchTodo(todoId),
);

// The "action" — submitting this invalidates todoQuery above,
// which then refetches on its own:
final updateTodo = BloomMutation<Todo, Todo>(
  mutateFn: api.updateTodo,
  invalidateKeys: [['todo', todoId]],
);
```

`BloomQuery` subscribes to `BloomData.onInvalidated(key)` and auto-refetches;
`BloomMutation.invalidateKeys` calls `BloomData.invalidateQueries(key)` on a
successful mutation. Pairing them with a shared cache key gives full
loader-revalidation-on-mutation semantics for free.
