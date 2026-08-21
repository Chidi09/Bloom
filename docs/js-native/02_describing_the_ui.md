# 02 — Describing the UI

In Bloom JS Native, you describe your user interface using standard, strongly-typed Dart AST constructors. There are no proprietary template languages, no JSX transpilers, and no runtime string parsers.

---

## 1. Standard HTML Elements

Bloom exports 38 `const` element builder classes matching semantic HTML5 elements:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildCard() {
  return Article(
    className: 'p-6 rounded-2xl bg-[#14141A] border border-[#1E1E24] shadow-xl',
    children: [
      Header(
        className: 'flex items-center justify-between mb-4',
        children: [
          H3(className: 'text-xl font-bold text-white', text: 'Deployment Pipeline'),
          Span(className: 'px-2.5 py-0.5 rounded-full text-xs font-mono bg-emerald-500/10 text-emerald-400', text: 'Active'),
        ],
      ),
      P(
        className: 'text-zinc-400 text-sm leading-relaxed mb-6',
        text: 'Automated CI/CD build running on edge worker clusters with sub-second execution.',
      ),
      Footer(
        className: 'flex gap-3',
        children: [
          Button(
            className: 'px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold',
            text: 'View Logs',
            onClick: (e) => print('Viewing logs...'),
          ),
          A(
            href: 'https://bloom.dev/docs',
            className: 'px-4 py-2 rounded-lg bg-[#1E1E24] hover:bg-[#27272A] text-zinc-300 text-xs font-semibold',
            text: 'Docs',
          ),
        ],
      ),
    ],
  );
}
```

### Supported HTML Elements

| Category | Elements |
| :--- | :--- |
| **Structure & Layout** | `Div`, `Span`, `Header`, `Footer`, `Main`, `Nav`, `Section`, `Article`, `Aside` |
| **Typography** | `H1`, `H2`, `H3`, `H4`, `H5`, `H6`, `P`, `Pre`, `Code`, `Blockquote`, `Strong`, `Em` |
| **Interactive & Forms** | `Button`, `Input`, `Textarea`, `Select`, `Option`, `Form`, `Label` |
| **Lists** | `Ul`, `Ol`, `Li` |
| **Media & Navigation** | `A`, `Img`, `Svg`, `Raw` |
| **Generic & Custom** | `El(tag, ...)`, `Fragment.fromList(...)` |

---

## 2. Element Attributes & Props

All element constructors accept strongly-typed common properties along with an extensible `attrs` map:

```dart
Input(
  type: 'email',
  placeholder: 'user@example.com',
  value: userEmail.value,
  className: 'w-full px-4 py-2.5 bg-black border border-zinc-800 rounded-xl text-sm text-white',
  attrs: {
    'id': 'user-email-input',
    'autocomplete': 'email',
    'aria-label': 'User email address',
    'data-testid': 'email-field',
  },
  onInput: (e) => userEmail.value = e.value ?? '',
)
```

---

## 3. Fragments (`Fragment` / `Fragment.fromList`)

When you need to return multiple sibling nodes without adding an extra wrapper `<div>` to the DOM:

```dart
BloomNode renderActionButtons() {
  return Fragment.fromList([
    Button(className: 'btn-secondary', text: 'Cancel'),
    Button(className: 'btn-primary', text: 'Confirm'),
  ]);
}
```

---

## 4. Conditional Rendering (`Show`)

The `Show` node conditionally mounts and unmounts subtrees based on a reactive predicate function:

```dart
final isLoggedIn = signal(false);
final userName = signal('Alex');

BloomNode renderAuthBar() {
  return Show(
    () => isLoggedIn.value,
    child: Div(
      className: 'flex items-center gap-3',
      children: [
        Live(() => Span(text: 'Welcome back, ${userName.value}!')),
        Button(text: 'Log out', onClick: (_) => isLoggedIn.value = false),
      ],
    ),
    fallback: Button(
      text: 'Log in with GitHub',
      onClick: (_) => isLoggedIn.value = true,
    ),
  );
}
```

> [!TIP]
> When `Show` toggles between `child` and `fallback`, any child `Live()` effects inside the unmounted branch are automatically disposed to prevent memory leaks.

---

## 5. Keyed List Rendering (`ForEach`)

When rendering collections, use `ForEach<T>()` with a `key` selector for **in-place DOM reconciliation**:

```dart
final todos = signal<List<({String id, String title, bool done})>>([
  (id: 'task-1', title: 'Compile JS Native bundle', done: true),
  (id: 'task-2', title: 'Write React-level documentation', done: false),
]);

BloomNode renderTodoList() {
  return Ul(
    className: 'space-y-2',
    children: [
      ForEach<({String id, String title, bool done})>(
        () => todos.value,
        (todo) => Li(
          className: 'p-3 rounded-lg bg-[#14141A] flex items-center justify-between',
          children: [
            Span(
              className: todo.done ? 'line-through text-zinc-500' : 'text-white',
              text: todo.title,
            ),
            Button(
              text: 'Delete',
              onClick: (_) => todos.value = todos.value.where((t) => t.id != todo.id).toList(),
            ),
          ],
        ),
        key: (todo) => todo.id, // Enables keyed in-place DOM updates
      ),
    ],
  );
}
```

---

## 6. XSS Protection & Raw HTML

All text strings passed to `Text()`, `text: '...'`, or element attributes are **automatically HTML-escaped** during both SSR and Browser mounting:

```dart
// Safely escaped as &lt;script&gt;alert(1)&lt;/script&gt;
P(text: '<script>alert(1)</script>')
```

When you need to insert verified raw HTML (such as vector SVGs or syntax-highlighted snippets), use `Raw()`:

```dart
Raw('''
<svg class="w-5 h-5 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
</svg>
''')
```
