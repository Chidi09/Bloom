# Bloom for React & JavaScript Developers: The Complete Architectural Guide

Welcome to the definitive guide for engineers transitioning from **React**, **Next.js**, **Vue**, **Svelte**, or **SolidJS** to the **Bloom full-stack ecosystem** and **Bloom JS Native**.

Bloom offers a unified, single-language stack powered by Dart. It combines the fine-grained reactive performance of SolidJS, the declarative ergonomics of React, and the full-stack batteries-included architecture of Next.js/Django, completely eliminating Virtual DOM overhead and GC churn.

---

## 1. Executive Summary & Paradigm Shift

If you know modern JavaScript and React, you already understand 80% of Bloom's conceptual architecture. However, Bloom eliminates several friction points that have plagued the JavaScript ecosystem for a decade:

* **Zero Virtual DOM Overhead**: In React, state changes trigger top-down component function re-executions and reconciliation diffing. Bloom uses **fine-grained Signals**; state changes mutate the exact target DOM nodes directly in `< 1 microsecond`.
* **Zero Component Re-Execution**: A Bloom component function executes **only once** during instantiation to build the reactive graph. Subsequent updates trigger only the granular signal subscriptions inside `Live()`, `Show()`, or `ForEach()`.
* **True Full-Stack Type Safety**: No code generation tools (like GraphQL codegen, Prisma generate, or tRPC) are needed to bridge client and server. Backend database models and frontend UI descriptors use the exact same immutable Dart classes.
* **Zero Runtime Node.js Dependency**: The Bloom toolchain runs on pure native binaries (Dart AOT / Bun). No `node_modules` hell, no Webpack config fatigue, no Babel transpilation lag.

---

## 2. Master Conceptual Rosetta Stone

| Concept | React / Next.js 14+ | Bloom JS Native |
| :--- | :--- | :--- |
| **Reactive State** | `const [count, setCount] = useState(0)` | `final count = signal(0)` |
| **Derived / Computed State** | `const double = useMemo(() => count * 2, [count])` | `final double = computed(() => count.value * 2)` |
| **Side Effects** | `useEffect(() => { ... }, [deps])` | `effect(() => { ... })` (auto-tracks dependencies) |
| **Untracked Reads** | `useRef` or omitting from dependency array | `untracked(() => count.value)` |
| **Batch Updates** | `unstable_batchedUpdates()` / React 18 auto-batch | `batch(() { a.value++; b.value++; })` |
| **Markup Syntax** | JSX (`<div className="card"><h1>{title}</h1></div>`) | Pure Dart AST (`Div(className: 'card', children: [H1(text: title)])`) |
| **Conditional Rendering** | `{isLoggedIn ? <Dashboard /> : <Login />}` | `Show(when: () => isLoggedIn.value, builder: () => Dashboard(), fallback: () => Login())` |
| **List Rendering** | `{items.map(item => <Item key={item.id} {...item} />)}` | `ForEach<Item>(() => items.value, (item) => ItemComponent(item), key: (item) => item.id)` |
| **Reactive Wrapper** | N/A (entire function re-runs) | `Live(() => Text(count.value.toString()))` |
| **Form Inputs** | Controlled: `value={val}` + `onChange={e => setVal(e.target.value)}` | `ShadcnInput.render(value: val.value, onInput: (e) => val.value = e.value ?? '')` |
| **NPM Package Management** | `npm install <pkg>` / `package.json` | `bloom add npm:<pkg>` / `bloom.yaml` (vendored via Bun) |
| **Server-Side Rendering (SSR)**| Next.js App Router (`renderToString`, 15–80ms latency) | Pure Dart `renderToHtml()` (`< 0.4ms` latency, 0kB baseline JS) |
| **Dev Server & HMR** | Vite / Webpack Dev Server | `bloom js dev` (SSE live reload channel `/_bloom_hr`, `-O0` fast compiler) |
| **Production Build** | `next build` / `vite build` | `bloom js build -O4` (whole-program tree-shaking & minification) |

---

## 3. Deep-Dive: Reactivity & State Management

### 3.1 Primitive Signals vs. React `useState`

In React, `useState` causes the entire enclosing component function to re-run from top to bottom, requiring careful hook order rules, `useCallback`, and `useMemo` to prevent unwanted child re-renders.

In Bloom, `signal<T>` creates an observable atomic value. Reading `.value` inside a reactive scope (`Live`, `computed`, `effect`) automatically subscribes that scope.

```dart
// 1. Declare primitive signal
final count = signal(0);
final query = signal('');

// 2. Read value
print(count.value); // 0

// 3. Mutate value
count.value++;
count.value = 42;

// 4. Update based on previous value
count.update((prev) => prev + 1);
```

### 3.2 Computed Signals vs. `useMemo`

`computed()` creates a read-only signal that lazily computes its value and caches it until its upstream dependencies change. Unlike `useMemo`, you **never specify a dependency array**—Bloom's dynamic dependency graph discovers dependencies at runtime.

```dart
final todos = signal<List<Task>>([]);
final filter = signal<'all' | 'active' | 'completed'>('all');

// Automatically re-computes only when `todos` or `filter` changes
final filteredTodos = computed(() {
  final currentFilter = filter.value;
  final currentList = todos.value;

  return switch (currentFilter) {
    'active' => currentList.where((t) => !t.isCompleted).toList(),
    'completed' => currentList.where((t) => t.isCompleted).toList(),
    _ => currentList,
  };
});
```

### 3.3 Effects & Cleanups vs. `useEffect`

`effect()` runs immediately and re-executes whenever any accessed signal changes. It automatically handles cleanup subscriptions via disposable regions (`_Region`).

```dart
// React Equivalent:
// useEffect(() => {
//   const timer = setInterval(() => tick(), 1000);
//   return () => clearInterval(timer);
// }, []);

// Bloom JS Native:
final dispose = effect(() {
  print('Current active user: ${currentUser.value.name}');

  // Optional teardown callback
  return () {
    print('Cleaning up previous effect run...');
  };
});

// To stop the effect permanently:
dispose();
```

### 3.4 Batching Updates

When updating multiple signals simultaneously, wrap them in `batch()` to ensure subscribers only notify once after all mutations have completed:

```dart
batch(() {
  user.value = newUser;
  isAuthenticated.value = true;
  lastLogin.value = DateTime.now();
}); // Downstream UI updates exactly once
```

---

## 4. Component Authoring: JSX vs. Pure Dart AST Descriptors

React uses JSX, an XML-like syntax transpiled by Babel/SWC into `React.createElement()` calls.

Bloom JS Native uses **Pure Dart AST Descriptors** (`package:bloom_js_native/bloom_js_native.dart`). Every HTML5 element is represented by a `const` subclass of `ElNode` (`Div`, `Span`, `Button`, `Section`, `Header`, `Nav`, `Table`, `Input`, `Form`, etc.).

### 4.1 Component Comparison

#### React Implementation:
```tsx
import React, { useState } from 'react';

interface MetricCardProps {
  label: string;
  initialValue: number;
  badgeText?: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({ label, initialValue, badgeText }) => {
  const [val, setVal] = useState(initialValue);

  return (
    <div className="p-4 rounded-xl bg-[#14141A] border border-[#1E1E24] shadow-sm">
      <div className="flex items-center justify-between">
        <span className="text-xs text-zinc-400 font-medium">{label}</span>
        {badgeText && (
          <span className="px-2 py-0.5 rounded-full text-[10px] bg-indigo-500/10 text-indigo-400">
            {badgeText}
          </span>
        )}
      </div>
      <div className="mt-2 flex items-center justify-between">
        <span className="text-xl font-mono font-bold text-white">{val}</span>
        <button
          onClick={() => setVal(v => v + 1)}
          className="px-3 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-xs text-white"
        >
          Increment
        </button>
      </div>
    </div>
  );
};
```

#### Bloom JS Native Implementation:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class MetricCard {
  final String label;
  final int initialValue;
  final String? badgeText;

  const MetricCard({
    required this.label,
    required this.initialValue,
    this.badgeText,
  });

  BloomNode build() {
    final val = signal(initialValue);

    return Div(
      className: 'p-4 rounded-xl bg-[#14141A] border border-[#1E1E24] shadow-sm',
      children: [
        Div(
          className: 'flex items-center justify-between',
          children: [
            Span(className: 'text-xs text-zinc-400 font-medium', text: label),
            if (badgeText != null)
              Span(
                className: 'px-2 py-0.5 rounded-full text-[10px] bg-indigo-500/10 text-indigo-400',
                text: badgeText!,
              ),
          ],
        ),
        Div(
          className: 'mt-2 flex items-center justify-between',
          children: [
            Live(() => Span(
              className: 'text-xl font-mono font-bold text-white',
              text: '${val.value}',
            )),
            Button(
              className: 'px-3 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-xs text-white transition-colors cursor-pointer',
              onClick: (_) => val.value++,
              text: 'Increment',
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## 5. Control Flow: Conditionals, Lists & Dynamic Views

### 5.1 Conditional Rendering with `Show`

Avoid ternary spaghetti inside complex layouts. `Show` accepts a boolean predicate and evaluates only the active branch:

```dart
Show(
  when: () => store.isLoading.value,
  builder: () => Div(className: 'animate-spin', children: [BloomIcons.loader()]),
  fallback: () => TaskListView(tasks: store.tasks),
)
```

### 5.2 Keyed List Rendering with `ForEach`

In React, omitting a `key` prop causes state mixing and re-rendering bugs. In Bloom, `ForEach<T>` provides fine-grained item reconciliation with explicit key functions:

```dart
Ul(
  className: 'divide-y divide-[#1E1E24]',
  children: [
    ForEach<Task>(
      () => store.tasks.value,
      (task) => TaskRowComponent(task: task, onToggle: () => store.toggleTask(task.id)),
      key: (task) => task.id,
    ),
  ],
)
```

---

## 6. Form Handling & Two-Way Data Binding

In Bloom, inputs can bind to standard event handlers or directly synchronize with signals:

```dart
final titleInput = signal('');
final priorityInput = signal(Priority.p3);

Div(
  className: 'space-y-4',
  children: [
    // Controlled Text Input
    Input(
      type: 'text',
      placeholder: 'Enter task title...',
      className: 'w-full p-2.5 bg-[#09090B] border border-[#27272A] rounded-lg text-xs text-white',
      value: titleInput.value,
      onInput: (BloomEvent e) {
        titleInput.value = e.value ?? '';
      },
    ),

    // Form Submission
    Button(
      text: 'Create Task',
      onClick: (_) {
        if (titleInput.value.trim().isEmpty) return;
        store.addTask(titleInput.value, priorityInput.value);
        titleInput.value = ''; // Reset input
      },
    ),
  ],
)
```

---

## 7. Using NPM Libraries Without `package.json`

Bloom introduces a zero-friction NPM integration engine. NPM packages are declared directly in your `bloom.yaml` manifest and assembled into ESM bundles via Bun or ESM CDNs:

### Step 1: Declare in `bloom.yaml`
```yaml
name: my_bloom_app
target: web_dom

npm:
  canvas-confetti: ^1.9.4
  lucide: ^1.33.0
  chart.js: ^4.4.1
```

### Step 2: Vendor Packages
```bash
bloom js vendor
```
This downloads minified ESM modules into `web/vendor/` and generates an inline HTML importmap:
```html
<script type="importmap">
{
  "imports": {
    "canvas-confetti": "./vendor/canvas-confetti.min.js",
    "chart.js": "./vendor/chart.js.min.js"
  }
}
</script>
```

### Step 3: Type-Safe Interop with `dart:js_interop`
```dart
import 'dart:js_interop';

@JS('confetti')
external void _fireConfetti(JSObject options);

void triggerCelebration() {
  final opts = JSObject();
  opts.setProperty('particleCount'.toJS, 100.toJS);
  opts.setProperty('spread'.toJS, 70.toJS);
  _fireConfetti(opts);
}
```

---

## 8. Server-Side Rendering (SSR) & Dynamic SEO

Bloom JS Native shares the exact same AST tree between the browser and Dart VM server.

### 8.1 Server Rendering (`< 0.4ms`)
```dart
// apps/server/lib/controllers/landing_controller.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

Future<BloomResponse> handleLandingPage(BloomRequest req) async {
  final head = HeadManager();
  head.update(
    title: 'Bloom — The Next Generation Full-Stack Framework',
    description: 'Ultra-high performance full-stack Dart framework.',
    ogImage: 'https://bloom.dev/og-image.png',
  );

  final app = LandingPageComponent();
  final html = renderToHtml(
    app.build(),
    title: head.title.value,
    metaTags: head.toMetaTags(),
  );

  return BloomResponse.html(html);
}
```

### 8.2 Dynamic SEO in SPA Client
On the browser client, `HeadManager` binds to your active navigation signals to update `<title>`, `<meta name="description">`, and OpenGraph headers reactively on route transitions:

```dart
final head = HeadManager();

effect(() {
  final activeView = store.activeNav.value;
  final taskCount = store.tasks.value.length;

  head.update(
    title: '${store.currentViewName} ($taskCount) — Bloom Workstation',
    ogTitle: store.currentViewName,
  );
  web.document.title = head.title.value;
});
```

---

## 9. Developer Workflow & CLI Commands

```bash
# 1. Start development server with Hot Live Reload
bloom js dev --port 8080

# 2. Build optimized production bundle (-O4 tree-shaking)
bloom js build

# 3. Analyze bundle size breakdown
bloom js build --analyze

# 4. Synchronize NPM vendor bundles
bloom js vendor

# 5. Run unit tests across Dart VM (0ms browser overhead)
dart test
```

---

## 10. Common React Pitfalls & Best Practices in Bloom

| Anti-Pattern in Bloom | Correct Bloom Pattern | Rationale |
| :--- | :--- | :--- |
| Wrapping whole component in `Live()` | Wrap only the exact dynamic `Text` or `Span` in `Live()` | Keeps DOM mutation surgical and eliminates unnecessary node recreation. |
| Mutating list in-place (`list.add(item)`) without reassigning signal | `signal.value = [...signal.value, item]` or `signal.update(...)` | Signals detect reference equality changes. |
| Passing callbacks deeply through props | Expose actions directly on your singleton or scoped `Store` | Eliminates prop-drilling without needing `useContext` boilerplate. |
| Importing `package:web/web.dart` in shared Store/API classes | Keep shared business logic in pure Dart (`package:http`) | Ensures models and stores remain 100% testable on Dart VM test runners. |
