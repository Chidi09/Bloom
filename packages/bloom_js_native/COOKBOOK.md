# Bloom JS Native Cookbook

A task-oriented recipe guide for building web applications with **Bloom JS Native**.

---

## 1. Orientation

Bloom JS Native is a pure Dart web UI framework based on lightweight AST descriptors (`BloomNode`) and fine-grained reactive signals (`signals`). It compiles directly to native JavaScript / WebAssembly with zero Flutter runtime dependencies.

The framework exposes two distinct entry points:
- `import 'package:bloom_js_native/bloom_js_native.dart';` — **Core / SSR-Safe**. Contains descriptor nodes (`Div`, `Button`, `Live`, `Show`, `ForEach`), signals (`signal`, `computed`, `effect`), form controllers, query/mutation managers, routing abstractions, i18n, and testing utilities. Pure Dart: runs on the Dart VM, during Server-Side Rendering (SSR), and in headless unit tests.
- `import 'package:bloom_js_native/browser.dart';` — **Browser-Only**. Contains DOM mounting (`mount`, `mountToElement`), hydration (`hydrate`, `hydrateElement`), browser routing (`BloomRouterController`), list virtualization (`BloomVirtualizer`), island hydration orchestration (`orchestrateIslands`), and Web Component interop (`customElement`, `defineCustomElement`). Depends on `package:web` and browser DOM APIs.

**The Golden Rule**: Never import `package:bloom_js_native/browser.dart` into code that runs on the server (SSR), inside Dart VM tests, or within universal shared libraries. Keep all business logic and component definitions in `bloom_js_native.dart`, and use `browser.dart` exclusively in your client-side `web/main.dart` entry point.

---

## 2. The Mental Model

Before writing recipes, internalize the core execution model:

### `BloomNode` is a Description, Not a Live Widget
When you call `Div(...)` or `Button(...)`, you are **not** creating a DOM element or a stateful widget instance. You are instantiating an immutable Dart data descriptor (`BloomNode`). The framework walks this descriptor tree to either:
1. Construct live DOM elements and attach reactive listeners in the browser (`mount()`).
2. Serialize static HTML strings in `< 1ms` on the server (`renderToHtml()`).

### `mount()` vs `renderToHtml()`
The exact same descriptor tree can be rendered by both backends:
- In the browser (`mount`), reactive boundaries (`Live`, `Show`, `ForEach`) mount between comment sentinels (`<!-- bloom:live -->`) and bind fine-grained signal effects that patch only the affected DOM slice.
- In SSR (`renderToHtml`), reactive boundaries evaluate their builder closures **exactly once synchronously** to emit static HTML.
- **What silently does nothing under SSR**: Event handlers (`onClick`, `onInput`), lifecycle hooks (`Mount.onMount`, `Mount.onUnmount`), imperative DOM references (`Ref`), client router listeners, and reactive signal effects. All of these run exclusively in the browser.

### Fine-Grained Reactivity & The #1 Beginner Bug
Reactivity is fine-grained to the nearest enclosing reactive boundary (`Live`, `Show`, `ForEach`). A signal read *inside* a `Live` builder registers a subscription and updates only that DOM slice when the signal value changes. Reading a signal *outside* a reactive region captures a one-time snapshot that never updates.

```dart
// ❌ WRONG: `count.value` is read once when `counterCard()` executes.
// The P element never updates when count changes!
BloomNode counterCard(Signal<int> count) {
  return Div(
    children: [
      P(text: 'Count: ${count.value}'), // BUG: Static snapshot!
      Button(text: '+1', onClick: (_) => count.value++),
    ],
  );
}

//  RIGHT: Wrap dynamic state reads inside a `Live` reactive boundary.
BloomNode counterCard(Signal<int> count) {
  return Div(
    children: [
      Live(() => P(text: 'Count: ${count.value}')), // Dynamically updates!
      Button(text: '+1', onClick: (_) => count.value++),
    ],
  );
}
```

### Disposal Contract
Any resource that binds external listeners, DOM observers, or event loops must be disposed when detached:
- `BloomMountHandle.unmount()` / `dispose()` — Tears down mounted DOM and disposes all nested effects.
- `BloomRouterController.dispose()` — Detaches `popstate` listeners and intersection observers.
- `BloomVirtualizer.dispose()` — Detaches scroll and resize observers.
- `BloomIslandOrchestrator.dispose()` — Disconnects island intersection and interaction triggers.
- `BloomController.onDispose()` — Disposes controller effects and registered cleanup callbacks.
- `BloomQuery.dispose()` / `BloomInfiniteQuery.dispose()` — Cancels cache invalidation subscriptions.

---

## 3. Project Structure & Multi-File Apps

`bloom create <name> --js-native` scaffolds a single `lib/main.dart` — fine for a demo, not for a real app. This section is the recommended layout once a project grows past one file. There is no code-generation or file-based routing step here (unlike `bloom create`'s Flutter templates) — Bloom JS Native routing is just the `BloomRoute` list from Section 9, so "file structure" is a convention, not a framework requirement, and you can deviate from it freely.

### Recommended layout

```
my_app/
  bloom.yaml
  pubspec.yaml
  AGENTS.md              # generated by `bloom create --js-native`; read this first
  web/
    index.html
    main.js               # compiled output — do not edit
  lib/
    main.dart              # entry point: builds the router, calls mount()
    app.dart                # top-level shell BloomNode (nav + Live(() => router.resolve()))
    routes/
      home_page.dart         # one BloomNode-returning function (or class) per route
      user_profile_page.dart
      not_found_page.dart
    components/
      button.dart             # shared, reusable BloomNode descriptors
      card.dart
    state/
      auth.dart                # shared Signal<T> instances + the functions that mutate them
      cart.dart
    design/
      tokens.dart               # designTokensCss const, injected via Style() — see Section 19
  test/
    smoke_test.dart
```

### How do I split components across files?
A component is just a function that returns a `BloomNode` (or takes a `Signal`/callback and returns one) — no special registration is required, so splitting is plain Dart file/import organization. Keep one component per file once a file exceeds a couple of screens of code, and name the file after the function.

```dart
// lib/components/card.dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode card({required String title, required List<BloomNode> children}) {
  return Div(
    className: 'card',
    children: [
      H2(text: title),
      ...children,
    ],
  );
}
```

```dart
// lib/routes/home_page.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/card.dart';

BloomNode homePage(Map<String, String> params) {
  return card(title: 'Welcome', children: [P(text: 'Hello from home_page.dart')]);
}
```

### How do I organize routes as one file per page?
Give each `BloomRoute` a matching file under `lib/routes/`, then assemble them in one place (`lib/app.dart` or directly in `lib/main.dart` for small apps) so the route list stays a single source of truth — exactly like the router example in Section 9, just with each `(params) => ...` builder imported from its own file instead of written inline.

```dart
// lib/app.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'routes/home_page.dart';
import 'routes/user_profile_page.dart';
import 'routes/not_found_page.dart';

final appRouter = BloomRouter([
  BloomRoute('/', homePage),
  BloomRoute('/users/:id', userProfilePage),
], notFound: BloomRoute('*', notFoundPage));

BloomNode appShell(BloomRouterController router) {
  return Div(children: [Live(() => router.resolve())]);
}
```

```dart
// lib/main.dart
import 'package:bloom_js_native/browser.dart';
import 'app.dart';

void main() {
  final router = BloomRouterController(appRouter);
  mount(appShell(router), '#app');
}
```

### Where should shared state live?
A `Signal<T>` is just a Dart object — put signals that more than one route/component reads or writes in `lib/state/`, exported as top-level `final` values (or wrapped in a small class if several signals belong together), and import them wherever needed. Keep signals that only one component cares about local to that component's own file instead of promoting them to `lib/state/` — see Section 5 for the difference between local and shared reactive state.

```dart
// lib/state/auth.dart
import 'package:bloom_js_native/bloom_js_native.dart';

final currentUser = signal<String?>(null);

void login(String name) => currentUser.value = name;
void logout() => currentUser.value = null;
```

### How should an AI coding agent approach this codebase?
Every project scaffolded with `bloom create --js-native` ships an `AGENTS.md` at its root — read that first; it points back to this cookbook and states the two-entry-point rule (Section 1) up front, since importing `bloom_js_native.dart` instead of `browser.dart` for `mount()` is the single most common mistake. When asked to add a page, follow the layout above: add one file under `lib/routes/`, register it in `lib/app.dart`'s `BloomRouter` list, and reuse existing files under `lib/components/` before writing a new descriptor from scratch.

---

## 4. Getting Something on Screen

### How do I create a minimal browser application?
Create a root component tree and mount it into an existing HTML container using a CSS selector.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  final app = Div(
    className: 'container',
    children: [
      H1(text: 'Hello, Bloom!'),
      P(text: 'Built with pure Dart AST descriptors.'),
    ],
  );

  mount(app, '#app');
}
```

Watch out: `mount` throws a `StateError` if the selector matching the target element is not present in `web.document`.

---

### How do I mount directly to an existing DOM Element?
When embedding Bloom into a third-party application or Web Component host where you already have a `web.Element` reference, use `mountToElement`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

void mountWidget(web.Element container) {
  final widget = Div(
    className: 'embedded-widget',
    text: 'Embedded into host container',
  );

  final handle = mountToElement(widget, container);

  // When tearing down:
  // handle.unmount();
}
```

---

### How do I set attributes, classes, and styles?
Use `className`, `style`, and the `attrs` map. Combine dynamic class names cleanly with `cx`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode statusBadge({required bool isOnline, required String label}) {
  return Span(
    className: cx([
      'badge',
      isOnline ? 'badge-success' : 'badge-danger',
    ]),
    style: 'display: inline-flex; align-items: center; gap: 6px;',
    attrs: {
      'role': 'status',
      'data-status': isOnline ? 'online' : 'offline',
    },
    text: label,
  );
}
```

---

### How do I handle DOM events?
Use named event parameters like `onClick`, `onInput`, `onChange`, `onSubmit`, or the general `on` map.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode interactiveForm() {
  return Form(
    onSubmit: (BloomEvent e) {
      e.preventDefault();
      // Handle form submission
    },
    children: [
      Input(
        placeholder: 'Type something...',
        onInput: (BloomEvent e) {
          final value = e.value; // Typed value getter on BloomEvent
        },
      ),
      Button(
        text: 'Submit',
        onClick: (BloomEvent e) {
          // Button click
        },
      ),
    ],
  );
}
```

Watch out: Standard HTML `<button>` elements inside `<form>` default to `type="submit"`. For standalone non-submitting buttons, set `attrs: const {'type': 'button'}`.

---

### How do I render plain text and fragments?
Use `Text` for explicit text leaf nodes and `Fragment` to group sibling nodes without creating a wrapper DOM element.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode breadcrumbNavigation() {
  return Nav(
    children: [
      // Not `const Fragment(...)`: Fragment has a const constructor, but the
      // A/Span children do not, so the surrounding const expression is invalid.
      Fragment(
        children: [
          A(href: '/', text: 'Home'),
          Span(text: ' / '),
          A(href: '/products', text: 'Products'),
          Span(text: ' / '),
          Span(className: 'active', text: 'Current Item'),
        ],
      ),
    ],
  );
}
```

---

## 5. State and Reactivity

### How do I declare reactive state with signals?
Use `signal` for mutable values, `computed` for derived read-only values, and `effect` for side effects.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);
final isEven = computed(() => count.value.isEven);

void setupLogger() {
  // Effects automatically track all signals read synchronously inside the callback
  final dispose = effect(() {
    // Runs immediately and whenever `count` changes
  });

  // Call dispose() when teardown is needed
}
```

---

### How do I update the UI when state changes?
Wrap dynamic subtree reads inside a `Live` node.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);

BloomNode counterView() {
  return Div(
    className: 'counter-card',
    children: [
      Live(() => H2(text: 'Current Count: ${count.value}')),
      Div(
        className: 'btn-group',
        children: [
          Button(text: '-1', onClick: (_) => count.value--),
          Button(text: '+1', onClick: (_) => count.value++),
        ],
      ),
    ],
  );
}
```

Watch out: Keep `Live` boundaries as granular as possible. Placing a single `Live` around your entire page forces the entire page tree to re-evaluate on any state change.

---

### How do I batch multiple signal updates?
Use `batch` to group multiple signal mutations so that subscribed computed signals and `Live` regions update only once.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final firstName = signal('Ada');
final lastName = signal('Lovelace');

void updateFullName(String first, String last) {
  batch(() {
    firstName.value = first;
    lastName.value = last;
  }); // Subscribed Live regions re-render only once after batch completes
}
```

---

### How do I read a signal without creating a reactive dependency?
Use `untracked` when you need to read a signal value inside an `effect` or `Live` boundary without subscribing to its future changes.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final activeQuery = signal('');
final telemetryEnabled = signal(true);

void logSearchQuery() {
  effect(() {
    final query = activeQuery.value; // Subscribes to activeQuery
    final shouldLog = untracked(() => telemetryEnabled.value); // Reads without subscribing

    if (shouldLog && query.isNotEmpty) {
      // Send telemetry
    }
  });
}
```

---

### How do I expose read-only state from a store?
Use `readonly()` to prevent external consumers from mutating internal signals.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class SessionStore {
  final _token = signal<String?>(null);

  // Expose as ReadonlySignal
  ReadonlySignal<String?> get token => _token.readonly();

  void login(String newToken) {
    _token.value = newToken;
  }

  void logout() {
    _token.value = null;
  }
}
```

---

### How do I manage complex state with a Reducer?
Use `useReducer` and `BloomReducer` when state transitions follow structured actions.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

sealed class CartAction {}
class AddItem extends CartAction { final String item; AddItem(this.item); }
class ClearCart extends CartAction {}

List<String> cartReducer(List<String> state, CartAction action) => switch (action) {
  AddItem(:final item) => [...state, item],
  ClearCart() => const [],
};

final cart = useReducer(cartReducer, const <String>[]);

BloomNode cartWidget() {
  return Div(
    children: [
      Live(() => P(text: 'Items in cart: ${cart.state.value.length}')),
      Button(
        text: 'Add Apple',
        onClick: (_) => cart.dispatch(AddItem('Apple')),
      ),
      Button(
        text: 'Clear',
        onClick: (_) => cart.dispatch(ClearCart()),
      ),
    ],
  );
}
```

---

### How do I encapsulate business logic in a `BloomController`?
Extend `BloomController` to bundle state, computed signals, lifecycle hooks, and automated cleanup.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class TimerController extends BloomController {
  final seconds = signal(0);
  late final ReadonlySignal<String> formatted;

  @override
  void onInit() {
    super.onInit();
    formatted = computed(() => '${seconds.value}s');

    // addEffect automatically disposes when controller is disposed
    addEffect(() {
      if (seconds.value >= 60) {
        // Handle milestone
      }
    });
  }

  void tick() => seconds.value++;
}
```

---

## 6. Lists and Conditionals

### How do I render conditional content?
Use `Show` with a reactive `when` predicate.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final isAuthenticated = signal(false);

BloomNode authSection() {
  return Show(
    () => isAuthenticated.value,
    child: Button(
      text: 'Log Out',
      onClick: (_) => isAuthenticated.value = false,
    ),
    fallback: Button(
      text: 'Log In',
      onClick: (_) => isAuthenticated.value = true,
    ),
  );
}
```

Watch out: If `fallback` is omitted and `when()` returns `false`, `Show` renders an empty fragment.

---

### How do I render a dynamic list with fine-grained keys?
Use `ForEach<T>` with a `key` extractor function.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class TaskItem {
  final String id;
  final String title;
  TaskItem(this.id, this.title);
}

final tasks = signal<List<TaskItem>>([
  TaskItem('task-1', 'Write documentation'),
  TaskItem('task-2', 'Review pull requests'),
]);

BloomNode taskListView() {
  return Ul(
    children: [
      ForEach<TaskItem>(
        () => tasks.value,
        // Keying is supplied by ForEach's own `key:` callback below;
        // Li itself has no `key:` parameter.
        (task) => Li(text: task.title),
        key: (task) => task.id,
      ),
    ],
  );
}
```

Watch out: Always provide `key` for lists whose items can be reordered, inserted, or removed. Unkeyed lists (`key == null`) tear down and recreate all child DOM nodes on every update.

---

### How do I prevent expensive subtrees from re-rendering with `Memo`?
Use `Memo<T>` to re-evaluate a subtree builder only when its extracted dependency value changes (`!=`).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final selectedUserId = signal('user-101');
final theme = signal('dark');

BloomNode userDetailsView() {
  return Div(
    children: [
      // Only re-runs when selectedUserId changes, even if theme changes!
      Memo<String>(
        () => selectedUserId.value,
        (id) => Div(
          className: 'user-profile',
          text: 'Loaded profile for ID: $id',
        ),
      ),
    ],
  );
}
```

---

### How do I virtualize a large list?
Use `BloomVirtualizer` from `package:bloom_js_native/browser.dart` to render only the visible viewport items.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

final items = List.generate(10000, (i) => 'Item #$i');
final scrollRef = Ref<web.Element>();

final virtualizer = BloomVirtualizer(
  scrollElementRef: scrollRef,
  count: () => items.length,
  estimateSize: (index) => 40.0,
  overscan: 5,
);

BloomNode virtualList() {
  return RefNode(
    scrollRef,
    Mount(
      Div(
        style: 'height: 400px; overflow-y: auto; position: relative;',
        children: [
          Live(() => Div(
            style: 'height: ${virtualizer.totalSize.value}px; position: relative; width: 100%;',
            children: virtualizer.items.value.map((item) {
              return Div(
                style: 'position: absolute; top: 0; left: 0; width: 100%; '
                       'height: ${item.size}px; transform: translateY(${item.start}px);',
                text: items[item.index],
              );
            }).toList(),
          )),
        ],
      ),
      onMount: virtualizer.attach,
      onUnmount: virtualizer.dispose,
    ),
  );
}
```

Watch out: `BloomVirtualizer` is browser-only (`browser.dart`). You must call `attach()` inside `Mount.onMount` and `dispose()` inside `Mount.onUnmount`.

---

### How do I lazily load a component?
Use `lazy()` to load a component bundle asynchronously while displaying a placeholder.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

Future<BloomNode> loadAnalyticsDashboard() async {
  await Future.delayed(const Duration(milliseconds: 300));
  return Div(text: 'Heavy Analytics Dashboard Loaded');
}

BloomNode dashboardPage() {
  return Div(
    children: [
      lazy(
        loadAnalyticsDashboard,
        fallback: Div(className: 'skeleton', text: 'Loading analytics...'),
      ),
    ],
  );
}
```

---

## 7. Forms

### How do I create a validated form input field?
Use `BloomFormField` with built-in validators like `required`, `minLength`, `maxLength`, `email`, and `pattern`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final emailField = BloomFormField(
  initialValue: '',
  validators: [
    required('Email address is required.'),
    email('Please enter a valid email address.'),
  ],
);

BloomNode emailInput() {
  return Div(
    children: [
      Label(text: 'Email Address'),
      Input(
        type: 'email',
        value: emailField.value.value,
        onInput: (e) {
          emailField.setValue(e.value ?? '');
          emailField.validate();
        },
        onBlur: (_) => emailField.touch(),
      ),
      Live(() {
        final errors = emailField.errors.value;
        if (errors.isEmpty || !emailField.isTouched.value) {
          return const Fragment(children: []);
        }
        return Span(className: 'error', text: errors.first);
      }),
    ],
  );
}
```

Watch out: Setting `emailField.setValue(...)` marks `isDirty` as `true` but does **not** validate automatically. Call `field.validate()` or `form.validate()` to execute validation rules.

---

### How do I manage strongly-typed fields?
Use `BloomTypedFormField<T>` (or `BloomField<T>`) with numeric, boolean, or custom models.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final ageField = BloomTypedFormField<int>(
  initialValue: 18,
  validators: [
    min(18, 'You must be at least 18 years old.'),
    max(120, 'Please enter a valid age.'),
  ],
);

final termsField = BloomTypedFormField<bool>(
  initialValue: false,
  validators: [
    requiredTrue('You must accept the terms of service.'),
  ],
);
```

---

### How do I handle file uploads?
Use `BloomFileField` with dedicated file validators (`fileRequired`, `maxFileSize`, `allowedExtensions`, `allowedMimeTypes`, `minFiles`, `maxFiles`).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final avatarUpload = BloomFileField(
  multiple: false,
  validators: [
    fileRequired('Please choose an avatar image.'),
    maxFileSize(2 * 1024 * 1024, 'Avatar must be under 2MB.'),
    allowedExtensions(['.png', '.jpg', '.webp']),
  ],
);
```

---

### How do I build dynamic repeating field arrays?
Use `BloomFieldArray<T>` to add, remove, and reorder controls reactively.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final skillsArray = BloomFieldArray<BloomFormField>(
  initialValues: [
    BloomFormField(initialValue: 'Dart', validators: [required()]),
  ],
);

BloomNode skillsEditor() {
  return Div(
    children: [
      Live(() => Ul(
        children: skillsArray.fields.value.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return Li(
            children: [
              Input(
                value: field.value.value,
                onInput: (e) => field.setValue(e.value ?? ''),
              ),
              Button(
                text: 'Remove',
                onClick: (_) => skillsArray.removeAt(index),
              ),
            ],
          );
        }).toList(),
      )),
      Button(
        text: 'Add Skill',
        onClick: (_) => skillsArray.add(BloomFormField(initialValue: '')),
      ),
    ],
  );
}
```

---

### How do I manage a complete form and handle submission?
Use `BloomForm` to coordinate validation, submission lifecycle (`isSubmitting`), and data retrieval.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final profileForm = BloomForm({
  'username': BloomFormField(validators: [required(), minLength(3)]),
  'email': BloomFormField(validators: [required(), email()]),
  'age': BloomTypedFormField<int>(initialValue: 21, validators: [min(18)]),
});

BloomNode userRegistrationForm() {
  return Form(
    onSubmit: (BloomEvent e) {
      e.preventDefault();
      profileForm.submitRaw((Map<String, dynamic> values) async {
        // Only called if all synchronous and asynchronous validators pass!
        // values contains: {'username': '...', 'email': '...', 'age': 21}
      });
    },
    children: [
      // Input elements...
      Live(() => Button(
        text: profileForm.isSubmitting.value ? 'Saving...' : 'Register',
        attrs: profileForm.isSubmitting.value ? const {'disabled': 'true'} : null,
      )),
    ],
  );
}
```

---

### How do I add asynchronous validators with debouncing?
Provide async validator callbacks that return a `Future<String?>`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final usernameField = BloomFormField(
  validators: [required()],
  asyncValidators: [
    (username) async {
      final isTaken = await checkUsernameAvailability(username);
      return isTaken ? 'This username is already taken.' : null;
    },
  ],
  asyncDebounce: const Duration(milliseconds: 400),
);

Future<bool> checkUsernameAvailability(String name) async => false;
```

---

### How do I wire form validation errors to the DOM accessibly?
Use `aria(describedBy: ..., invalid: ...)` to connect error messages to inputs for assistive technologies.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode accessibleField(String id, String labelText, BloomFormField field) {
  return Div(
    children: [
      Label(attrs: {'for': id}, text: labelText),
      Live(() {
        final hasError = field.errors.value.isNotEmpty && field.isTouched.value;
        return Input(
          attrs: {
            'id': id,
            ...aria(
              invalid: hasError,
              describedBy: hasError ? '$id-error' : null,
            ),
          },
          onInput: (e) {
            field.setValue(e.value ?? '');
            field.validate();
          },
          onBlur: (_) => field.touch(),
        );
      }),
      Live(() {
        final errors = field.errors.value;
        if (errors.isEmpty || !field.isTouched.value) {
          return const Fragment(children: []);
        }
        return Span(
          attrs: {'id': '$id-error'},
          className: 'error-text',
          text: errors.first,
        );
      }),
    ],
  );
}
```

---

## 8. Data Fetching and Mutations

### How do I fetch data with `BloomQuery`?
Use `query<T>` to fetch and cache data with automatic request deduplication and background revalidation.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final http = BloomHttpClient(baseUrl: 'https://api.example.com');

final productsQuery = query<List<dynamic>>(
  key: const ['products'],
  fetch: () => http.get<List<dynamic>>('/products'),
  staleTime: const Duration(minutes: 5),
);

BloomNode productListView() {
  return Live(() => switch (productsQuery.status.value) {
    QueryStatus.loading => P(text: 'Loading products...'),
    QueryStatus.error => P(text: 'Error: ${productsQuery.error.value}'),
    QueryStatus.success => Ul(
        children: (productsQuery.data.value ?? const []).map((item) {
          return Li(text: item.toString());
        }).toList(),
      ),
    QueryStatus.idle => const Fragment(children: []),
  });
}
```

---

### How do I execute mutations and invalidate queries?
Use `mutation<T, P>` to perform `POST`/`PUT`/`DELETE` operations and automatically invalidate affected query keys upon success.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final http = BloomHttpClient(baseUrl: 'https://api.example.com');

final createTodo = mutation<Map<String, dynamic>, String>(
  mutate: (title) => http.post<Map<String, dynamic>>('/todos', body: {'title': title}),
  invalidateKeys: const [
    ['todos'], // Automatically triggers background refetch for `query(['todos'])`
  ],
  onError: (err, title, context) {
    // Handle failure
  },
);

void handleAddTodo(String title) {
  createTodo.mutate(title);
}
```

---

### How do I perform optimistic updates with automatic rollback?
Configure `optimisticKey` and `optimisticData` on your mutation. If the network call throws, `BloomMutation` automatically restores the cache snapshot.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final http = BloomHttpClient(baseUrl: '/api');

// The first type argument is the type of the CACHED data at `optimisticKey`,
// not the HTTP response body -- `optimisticData` is typed
// `T? Function(P params, T? oldData)`. The todo list is cached as a list, so
// T is List<dynamic> here; using `void` makes the updater unable to return one.
final toggleTodo = mutation<List<dynamic>, String>(
  mutate: (todoId) => http.patch<List<dynamic>>('/todos/$todoId/toggle'),
  optimisticKey: const ['todos'],
  optimisticData: (todoId, oldTodos) {
    final list = oldTodos ?? const [];
    return list.map((item) {
      if (item is Map<String, dynamic> && item['id'] == todoId) {
        return {...item, 'done': !(item['done'] as bool? ?? false)};
      }
      return item;
    }).toList();
  },
  invalidateKeys: const [
    ['todos'],
  ],
);
```

---

### How do I load paginated / infinite data?
Use `infiniteQuery<TPage, TParam>` to accumulate pages with a "Load More" trigger.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final http = BloomHttpClient(baseUrl: 'https://api.example.com');

final feedQuery = infiniteQuery<List<dynamic>, int>(
  key: const ['feed'],
  initialPageParam: 0,
  fetch: (offset) => http.get<List<dynamic>>('/feed?offset=$offset&limit=10'),
  getNextPageParam: (lastPage, allPages) =>
      lastPage.length == 10 ? allPages.length * 10 : null,
);

BloomNode feedView() {
  return Div(
    children: [
      Live(() => Ul(
        children: feedQuery.items.map((item) => Li(text: item.toString())).toList(),
      )),
      Live(() => Show(
        () => feedQuery.hasNextPage.value,
        child: Button(
          text: feedQuery.isFetchingNextPage.value ? 'Loading...' : 'Load More',
          onClick: (_) => feedQuery.fetchNextPage(),
        ),
      )),
    ],
  );
}
```

---

### How do I dehydrate cache state during SSR and hydrate on the client?
Serialize the server's cache state to an HTML script tag with `BloomData.dehydrateToScriptTag`, then restore it on the client with `BloomData.hydrateFromJson`.

**Server-Side Rendering (SSR)**:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';

String buildPageHtml(BloomNode app) {
  final content = renderToHtml(app);
  final cacheScript = BloomData.dehydrateToScriptTag(); // Emits <script id="__BLOOM_DATA__">

  return '<!DOCTYPE html><html><body><div id="app">$content</div>$cacheScript</body></html>';
}
```

**Client-Side Entry Point**:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

void main() {
  final scriptEl = web.document.getElementById('__BLOOM_DATA__');
  if (scriptEl != null && scriptEl.textContent != null) {
    BloomData.hydrateFromJson(scriptEl.textContent!);
  }

  mount(App(), '#app'); // Queries read directly from cached state without refetching!
}

/// Your own root component.
BloomNode App() => Div(text: 'App root');
```

---

## 9. Routing

### How do I configure client-side routes and parameters?
Define a `BloomRouter` and drive the browser DOM using `BloomRouterController`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

late final BloomRouterController router;

final appRouter = BloomRouter([
  BloomRoute('/', (params) => H1(text: 'Home Page')),
  BloomRoute('/users/:id', (params) => H1(text: 'User Profile: ${params['id']}')),
  BloomRoute('/docs/*', (params) => H1(text: 'Doc Path: ${params['wildcard']}')),
], notFound: BloomRoute('*', (params) => H1(text: '404 Not Found')));

void main() {
  router = BloomRouterController(appRouter);

  final app = Div(
    children: [
      Live(() => router.resolve()),
    ],
  );

  mount(app, '#app');
}
```

---

### How do I read and mutate query parameters and hash fragments?
Use `router.currentQuery`, `router.currentFragment`, `navigateQuery`, and `setFragment`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

BloomNode searchControls(BloomRouterController router) {
  return Div(
    children: [
      Live(() => P(text: 'Query: ${router.currentQuery.value['q'] ?? ''}')),
      Button(
        text: 'Filter Shoes',
        onClick: (_) => router.navigateQuery({'q': 'shoes', 'page': 1}),
      ),
      Button(
        text: 'Jump to Section',
        onClick: (_) => router.navigateFragment('specs'),
      ),
    ],
  );
}
```

---

### How do I protect routes with navigation guards?
Implement `BloomRouteGuard` and return `GuardResult.allow()` or `GuardResult.redirect(...)`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class AuthGuard extends BloomRouteGuard {
  final bool Function() isAuthenticated;
  const AuthGuard(this.isAuthenticated);

  @override
  GuardResult canActivate(String location, Map<String, String> params) {
    if (!isAuthenticated()) {
      return GuardResult.redirect('/login');
    }
    return GuardResult.allow();
  }
}

final protectedRoute = BloomRoute(
  '/dashboard',
  (params) => H1(text: 'Secret Dashboard'),
  guards: [AuthGuard(() => checkUserLoggedIn())],
);

bool checkUserLoggedIn() => true;
```

---

### How do I create persistent layout shells?
Use `BloomRoute.shell` to wrap sub-routes with persistent sidebars and navigation headers.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final rootRoutes = [
  BloomRoute.shell(
    layout: (child, params) => Div(
      className: 'app-shell',
      children: [
        // Nav takes no `text:` shorthand -- pass a Text child instead.
        Nav(children: [const Text('Sidebar Navigation')]),
        Main(children: [child]),
      ],
    ),
    routes: [
      BloomRoute('/dashboard', (params) => H1(text: 'Dashboard Content')),
      BloomRoute('/settings', (params) => H1(text: 'Settings Content')),
    ],
  ),
];
```

---

### How do I navigate with prefetching links?
Use `Link` with `PrefetchMode.hover` or `PrefetchMode.visible`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode navigationBar() {
  return Nav(
    children: [
      Link(href: '/', text: 'Home'),
      // Prefetches route when user hovers over link
      Link(href: '/pricing', prefetch: PrefetchMode.hover, text: 'Pricing'),
      // Prefetches route when link scrolls into viewport
      Link(href: '/features', prefetch: PrefetchMode.visible, text: 'Features'),
    ],
  );
}
```

---

## 10. Server-Side Rendering (SSR) & Hydration

### How do I render HTML strings on the server?
Call `renderToHtml` on any `BloomNode` tree.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void handleHttpRequest() {
  final page = Div(
    className: 'landing-page',
    children: [
      H1(text: 'Bloom SSR'),
      P(text: 'Rendered in pure Dart with full HTML escaping.'),
    ],
  );

  final html = renderToHtml(page);
  // Send html to HTTP client
}
```

---

### How do I render a complete HTML5 document?
Use `renderToDocument` to emit `<!DOCTYPE html>` with headers, stylesheets, and scripts.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

String generateFullDocument(BloomNode bodyNode) {
  return renderToDocument(
    bodyNode,
    title: 'Bloom Application',
    lang: 'en',
    stylesheets: ['/styles/bundle.css'],
    scripts: ['/client/main.dart.js'],
  );
}
```

---

### How do I stream HTML with out-of-order Suspense resolution?
Use `renderToStreamWithSuspense` to flush the document shell immediately and stream resolved `<Suspense>` chunks as background futures complete.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

Stream<String> streamPage() {
  final tree = Div(
    children: [
      H1(text: 'Instant Document Shell'),
      Suspense<String>(
        resource: () => Future.delayed(const Duration(seconds: 1), () => 'Loaded Async Data'),
        fallback: Div(text: 'Loading async content...'),
        builder: (data) => Div(text: 'Data: $data'),
      ),
    ],
  );

  return renderToStreamWithSuspense(tree);
}
```

---

### How do I hydrate server-rendered HTML in the browser?
Use `hydrate` from `browser.dart`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  final app = Div(
    className: 'card',
    children: [
      H1(text: 'Server Rendered Header'),
      Button(text: 'Click', onClick: (_) => print('Clicked!')),
    ],
  );

  // Attaches event listeners in-place without rebuilding DOM
  hydrate(app, '#app');
}
```

Watch out: In-place hydration works on static descriptor nodes (`ElNode`, `TextNode`, `FragmentNode`). If dynamic sentinel nodes (`Live`, `Show`, `ForEach`) are encountered during hydration, the hydrator safely falls back to a clean client mount (`mountToElement`) to ensure complete reactivity.

---

### How do I use Islands Architecture for selective hydration?
Use `bloomIsland` / `BloomIsland` on the server and `registerIsland` + `orchestrateIslands` on the client.

**Server SSR Page**:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode serverRenderedPage() {
  return Div(
    children: [
      H1(text: 'Static Blog Article'),
      P(text: 'Zero JS required for reading this content.'),
      // Interactive Island
      bloomIsland(
        name: 'comments-box',
        strategy: HydrationStrategy.visible,
        props: {'articleId': 42},
        child: Div(className: 'skeleton', text: 'Loading comments...'),
      ),
    ],
  );
}
```

**Client Browser Entry Point**:
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  registerIsland('comments-box', (props) {
    final articleId = props['articleId'] as int;
    final text = signal('');

    return Div(
      className: 'comments-container',
      children: [
        H3(text: 'Comments for Article #$articleId'),
        Input(onInput: (e) => text.value = e.value ?? ''),
        Button(text: 'Post Comment', onClick: (_) => print('Comment: ${text.value}')),
      ],
    );
  });

  // Discovers all `data-bloom-island` placeholders and initializes intersection observers
  orchestrateIslands();
}
```

---

## 11. Styling

### How do I use Scoped CSS modules?
Use `scopedCss` to generate deterministic class names that match bit-for-bit across SSR and client hydration.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final cardStyles = scopedCss('''
  .card {
    padding: 16px;
    background: #14141a;
    border: 1px solid #27272a;
    border-radius: 8px;
  }
  .card:hover {
    border-color: #6366f1;
  }
  .title {
    font-size: 18px;
    font-weight: 600;
    color: #ffffff;
  }
  :global(.dark) .card {
    background: #09090b;
  }
''', name: 'card');

BloomNode styledCard(String titleText) {
  return Div(
    className: cardStyles['card'],
    children: [
      cardStyles.node, // Injects <style> block
      H1(className: cardStyles['title'], text: titleText),
    ],
  );
}
```

---

### How do I configure CSP Nonces for injected stylesheets?
Set `bloomStyleNonce` before mounting in the browser.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  bloomStyleNonce = 'rAnd0mN0nc3Str1ng';
  mount(App(), '#app'); // All injected <style> tags receive nonce="rAnd0mN0nc3Str1ng"
}

/// Your own root component.
BloomNode App() => Div(text: 'App root');
```

---

## 12. Interop and Web Components

### How do I consume a Web Component / Custom Element?
Use `customElement` to render custom elements, pass rich properties via JS interop, and listen to custom events.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
// Web Component support is browser-only, so it lives in browser.dart rather
// than the main barrel (which stays safe to import from VM/SSR code).
import 'package:bloom_js_native/browser.dart';

BloomNode datePickerWidget() {
  return customElement(
    'sl-select',
    attrs: {
      'placeholder': 'Select an option',
    },
    properties: {
      'value': 'option-1',
    },
    events: {
      'sl-change': (CustomElementEvent<dynamic> event) {
        // Deserialized event.detail
      },
    },
  );
}
```

---

### How do I author and register a Web Component in pure Dart?
Use `defineCustomElement` from `browser.dart`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void registerUserBadgeElement() {
  defineCustomElement(
    'user-badge',
    (CustomElementContext context) {
      final nameSignal = context.attributeSignal('user-name');

      return Live(() => Div(
        className: 'badge',
        children: [
          Span(text: 'User: ${nameSignal.value ?? 'Guest'}'),
          Button(
            text: 'Ping',
            onClick: (_) => context.dispatchCustomEvent('ping', detail: {'time': DateTime.now().toIso8601String()}),
          ),
        ],
      ));
    },
    observedAttributes: ['user-name'],
  );
}
```

Watch out: `defineCustomElement` relies on runtime JavaScript constructor evaluation (`eval`) under the hood and will fail under strict Content Security Policies that disallow `unsafe-eval`. Consuming third-party custom elements via `customElement()` does not use `eval` and is fully CSP-compliant.

---

### How do I register npm dependencies and generate an ESM Import Map?
Use `NpmRegistry` and `NpmDependency`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void configureNpmImports() {
  NpmRegistry.registerAll([
    const NpmDependency('canvas-confetti', '^1.9.2'),
    const NpmDependency('dayjs', '^1.11.10'),
    const NpmDependency('lucide', '0.344.0', importAs: 'lucide-icons', subPath: 'icons'),
  ]);

  final importMapTag = NpmRegistry.generateImportMapTag(); // Emits <script type="importmap">...</script>
}
```

`NpmRegistry` above is the manual, in-Dart-code path — useful if you're generating the import map yourself at build time. For everyday use, prefer the CLI-driven workflow below: it downloads the real package, generates typed Dart bindings for you, and wires everything into `web/index.html` automatically.

---

### How do I actually install and call an npm package? (the `bloom add` workflow)

Run `bloom add npm:<package>` (or just `bloom add <package>` inside a project whose `bloom.yaml` has `target: web_dom` — every `--js-native` scaffold does, so the `npm:` prefix is optional there). This single command:

1. Downloads a real ESM bundle for the package from esm.sh into `web/vendor/<package>.min.js`.
2. Generates a typed Dart `@JS()` interop binding at `lib/src/plugins/<package>.dart` — parsed from the package's real `.d.ts` type declarations when available, so the member names it emits are the package's actual exports, not guesses.
3. Adds the package to the `<script type="importmap">` block in `web/index.html`, and adds a second `<script type="module">` "bootstrap" block that imports the vendored module and assigns it onto a `window` global (`window.<packageName>`) — this is what your generated `@JS('<global>')` binding reads from. Both blocks are regenerated automatically on every `bloom js dev` / `bloom js build`, so they always match what's declared in `bloom.yaml`'s `npm_packages` section.
4. Records the package in `bloom.yaml` under `npm_packages`, so a teammate (or CI) can reproduce your exact vendor setup by re-running `bloom js dev`/`bloom js build` — no `node_modules`, no separate JS package manager.

```
bloom add npm:dayjs
# ✓ ESM bundle ready: web/vendor/dayjs.min.js
# ✓ Dart interop binding generated: lib/src/plugins/dayjs.dart
# ✓ Updated <script type="importmap"> in web/index.html
# ✓ Recorded in bloom.yaml
```

Then import and call the generated binding directly — no manual `@JS()` writing required. For a package like `dayjs`, whose `.d.ts` exposes top-level members (`extend`, `locale`, `isDayjs`, `unix`, ...), the generated binding is directly callable:

```dart
import 'dart:js_interop';
import '../src/plugins/dayjs.dart'; // path relative to lib/, generated by `bloom add npm:dayjs`

void configureLocale() {
  // `dayjs` here is the top-level getter the binding generated — it reads
  // window.dayjs, which the auto-generated bootstrap script in
  // web/index.html populated for you. `.locale(...)` is a real member the
  // generator found in dayjs's own .d.ts.
  dayjs.locale('en'.toJS);
}
```

Watch out — read the generated file before trusting it, every time:
- The generator's member list is a best-effort parse of the package's `.d.ts`. If a package ships no usable type declarations, it falls back to a single guessed member and says so in a doc comment right above it — do not call that member without verifying it against the package's real docs first.
- The binding models the package as "an object with methods." It does not special-case a JS API whose entry point is itself a callable function that returns a new chainable instance (`dayjs()` returning a day object you then call `.format()` on, for example) — that pattern needs a hand-written `@JS()` addition on top of the generated file. The generated file is a starting point for object-shaped APIs, not a universal JS-interop solution; extend it the same way you would hand-write any other `@JS()` binding when a package's real usage doesn't fit the "namespace object with methods" shape.

To remove a package (deletes its vendor file, import map entry, and bootstrap wiring): `bloom remove <package>`.

---

### How do I use Tailwind CSS without a CDN `<script>` tag or a build step?

Install the official in-browser Tailwind engine the same way as any other package:

```
bloom add npm:@tailwindcss/browser
```

This is a special case of the workflow above: `@tailwindcss/browser` has no JS API to call from Dart (it's a side-effect-only module — importing it scans the DOM for utility classes and injects a `<style>` tag), so `bloom add` skips generating a Dart binding for it and instead writes a dedicated self-executing `<script type="module">import '@tailwindcss/browser';</script>` into `web/index.html`, alongside the usual importmap entry. No CDN `<script src="https://cdn.tailwindcss.com">` (unpinned, un-vendored, blocks on a network fetch every load) and no separate build step (`tailwindcss -i ... -o ...`) — the engine JIT-compiles whatever utility classes it finds in the live DOM, every time the DOM changes.

Then just use utility classes in `className`, exactly like any other framework:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode pricingCard() {
  return Div(
    className: 'flex flex-col gap-2 p-6 rounded-xl bg-slate-900 text-white shadow-lg',
    children: [
      H2(text: 'Pro Plan', className: 'text-xl font-semibold'),
      P(text: '\$29/mo', className: 'text-3xl font-bold text-indigo-400'),
    ],
  );
}
```

Watch out: because Tailwind's browser engine scans rendered DOM, not your Dart source, it only sees classes that actually end up in the DOM. A class name built by string interpolation (`'text-${size}'`) works fine once mounted (the engine reads real attribute values, not your source text) — but don't confuse this with Tailwind's static CLI/PostCSS builds elsewhere, which scan source files as text and do need whole, unbroken class names to find via regex. The in-browser engine has no such restriction.

---

## 13. Internationalization (i18n) and Images

### How do I define message catalogs and translate strings?
Use `BloomCatalog`, `BloomI18n`, and `t` / `tr`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final enCatalog = BloomCatalog('en-US', {
  'greeting': 'Hello, {name}!',
  'cart_summary': '{count, plural, =0 {No items in cart} =1 {1 item in cart} other {# items in cart}}',
  'gender_action': '{gender, select, female {She shared} male {He shared} other {They shared}} a link.',
});

void initTranslations() {
  BloomI18n.instance.addCatalog(enCatalog);
  BloomI18n.instance.setLocale('en-US');
}

BloomNode greetingWidget(String userName, int itemCount) {
  return Div(
    children: [
      Live(() => H1(text: t('greeting', args: {'name': userName}))),
      Live(() => P(text: tr('cart_summary', {'count': itemCount}))),
    ],
  );
}
```

Watch out: Built-in number and date formatting functions (`formatNumber`, `formatDate`) use a lightweight pure-Dart translation engine covering major language families. They do not bundle the entire Unicode CLDR dataset.

---

### How do I switch locales reactively?
Call `setLocale` to update the active locale signal globally across all active `t()` calls.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode languagePicker() {
  return Div(
    children: [
      Button(text: 'English', onClick: (_) => setLocale('en-US')),
      Button(text: 'Deutsch', onClick: (_) => setLocale('de-DE')),
      Button(text: 'Français', onClick: (_) => setLocale('fr-FR')),
    ],
  );
}
```

---

### How do I render responsive images with LCP optimization?
Use `bloomImage` with `priority: true` for above-the-fold hero images to configure `FetchPriority.high` and `ImageLoading.eager`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode heroBanner() {
  return bloomImage(
    src: '/assets/hero.webp',
    alt: 'Bloom Framework Hero',
    width: 1200,
    height: 600,
    widths: [400, 800, 1200],
    sizes: '(max-width: 768px) 100vw, 1200px',
    priority: true, // Optimizes for Largest Contentful Paint (LCP)
    fit: ImageFit.cover,
  );
}
```

---

### How do I render art-directed `<picture>` elements?
Use `bloomPicture` with `PictureSource` definitions.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode responsiveHeroPicture() {
  return bloomPicture(
    fallbackSrc: '/images/hero-desktop.jpg',
    alt: 'Hero visual',
    sources: [
      PictureSource(
        src: '/images/hero-mobile.webp',
        media: '(max-width: 640px)',
        type: 'image/webp',
      ),
      PictureSource(
        src: '/images/hero-desktop.webp',
        media: '(min-width: 641px)',
        type: 'image/webp',
      ),
    ],
  );
}
```

---

## 14. Accessibility (a11y)

### How do I generate WAI-ARIA attributes?
Use `aria(...)` and the `.withAria(...)` map extension.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode tabButton({required bool isSelected, required String controlsId, required String label}) {
  return Button(
    attrs: {
      ...aria(
        role: AriaRole.tab,
        selected: isSelected,
        controls: controlsId,
      ),
    },
    text: label,
  );
}
```

---

### How do I broadcast screen-reader announcements?
Place a `LiveRegion` once in your root tree and broadcast messages with `BloomAnnouncer`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode appRoot(BloomNode pageContent) {
  return Div(
    children: [
      LiveRegion(), // Accessible polite and assertive live regions
      pageContent,
    ],
  );
}

void notifyUser(String message) {
  BloomAnnouncer.instance.announcePolite(message);
}
```

---

### How do I hide text visually while keeping it screen-reader accessible?
Use `VisuallyHidden` or the `visuallyHiddenStyle` constant.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode deleteButton() {
  return Button(
    children: [
      Span(className: 'icon-trash', text: '🗑️'),
      VisuallyHidden(text: 'Delete record'), // Accessible to screen readers only
    ],
  );
}
```

---

## 15. Performance and Scheduling

### How do I defer non-urgent state updates with transitions?
Use `startTransition` and `isTransitionPending` to keep high-frequency inputs responsive while deferring heavy computations.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final searchInput = signal('');
final filteredResults = signal<List<String>>([]);

BloomNode searchView() {
  return Div(
    children: [
      Input(
        onInput: (e) {
          // Urgent update: immediately update input text
          searchInput.value = e.value ?? '';

          // Non-urgent update: schedule filtering at low priority
          startTransition(() {
            filteredResults.value = performExpensiveSearch(searchInput.value);
          });
        },
      ),
      Live(() => isTransitionPending.value
          ? Span(text: 'Searching...')
          : const Fragment(children: [])),
    ],
  );
}

List<String> performExpensiveSearch(String query) => [];
```

---

### How do I time-slice cooperative background tasks?
Use `BloomScheduler.schedule` with `TaskPriority`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void processAnalyticsData(List<dynamic> records) {
  BloomScheduler.schedule(() async {
    for (final record in records) {
      processRecord(record);

      // Yields to the browser event loop if frame budget is exceeded
      if (BloomScheduler.shouldYield()) {
        await BloomScheduler.yieldNow();
      }
    }
  }, priority: TaskPriority.low);
}

void processRecord(dynamic record) {}
```

---

## 16. Testing

### How do I write headless VM unit tests for components?
Use `renderForTest` and `fireEvent` to test component ASTs in standard `dart test` without a browser.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

BloomNode counterComponent(Signal<int> count) {
  return Div(
    attrs: {'data-testid': 'root'},
    children: [
      Live(() => Span(attrs: {'data-testid': 'count'}, text: 'Count: ${count.value}')),
      Button(
        attrs: {'data-testid': 'increment-btn'},
        text: 'Increment',
        onClick: (_) => count.value++,
      ),
    ],
  );
}

void main() {
  test('increments counter on button click', () {
    final count = signal(0);
    final renderer = renderForTest(counterComponent(count));

    expect(renderer.getByTestId('count').text, 'Count: 0');

    final btn = renderer.getByTestId('increment-btn');
    fireEvent.click(btn);

    expect(count.value, 1);
    expect(renderer.getByTestId('count').text, 'Count: 1');
  });
}
```

---

## 17. Error Handling

### How do I catch rendering exceptions with `ErrorBoundary`?
Wrap fallible subtrees in an `ErrorBoundary` descriptor.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode safeWidget() {
  return ErrorBoundary(
    builder: () => Div(
      children: [
        H2(text: 'Telemetry Dashboard'),
        riskySubtree(),
      ],
    ),
    fallback: (error, stackTrace) => Div(
      className: 'error-card',
      children: [
        H3(text: 'Failed to load telemetry'),
        P(text: error.toString()),
      ],
    ),
  );
}

BloomNode riskySubtree() => Div();
```

Watch out: Error boundaries in Bloom JS Native catch exceptions during initial mounting, reactive effect rebuilds, and `Suspense` failures. Once tripped, an error boundary has no automatic retry or reset mechanism; the subtree displays the fallback until the parent component or application remounts.

---

## 18. Backend-for-Frontend (BFF)

### How do I proxy /api to a co-located Bloom server in dev?
When developing full-stack applications with `bloom js dev`, the dev server automatically supervises `bin/server.dart` on port `8090` and configures a same-origin dev proxy route for `/api`.

Calls from your browser application to `/api/...` are made directly against the same origin as your web page (e.g. `http://localhost:8080/api/tasks`), eliminating CORS preflights and cross-origin blocking entirely.

You can also customize or declare explicit proxy rules in `bloom.yaml`:

```yaml
# bloom.yaml
name: my_bloom_app
version: 1.0.0

proxy:
  "/api":
    target: "http://127.0.0.1:8090"
```

When `bloom js dev` runs, it prints all active proxy routes at startup:
```text
› Proxy: /api ➔ http://127.0.0.1:8090
```

---

### How do I proxy a third-party API to defeat CORS?
Cross-Origin Resource Sharing (CORS) is a security mechanism enforced exclusively by web browsers to restrict client scripts from making requests to a different domain unless the destination server explicitly returns permissive CORS headers (`Access-Control-Allow-Origin`).

Server-to-server HTTP requests are **not** subject to browser CORS policies. Therefore, the architectural solution for consuming third-party APIs from a browser frontend is to proxy the request through your Backend-for-Frontend (BFF) layer.

Declare the third-party upstream route in `bloom.yaml` with `strip_prefix: true`:

```yaml
# bloom.yaml
proxy:
  "/gh":
    target: "https://github-contributions-api.jogruber.de"
    strip_prefix: true
```

In your client application, call the local same-origin path:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final client = BloomHttpClient();

Future<Map<String, dynamic>> fetchUserContributions(String username) async {
  // Browser fetches from same-origin /gh/v4/...
  // Dev server strips '/gh' and forwards to https://github-contributions-api.jogruber.de/v4/...
  return client.get<Map<String, dynamic>>('/gh/v4/$username');
}
```

---

### How do I call a typed RPC endpoint end-to-end?
Declare a shared `BloomRpcContract` across client and server packages, implement the contract handler with `BloomRpcRouter` on the backend, mount it to `BloomApiRouter`, and execute it with type safety on the client using `BloomRpcClient` or `rpcQuery`.

#### 1. Define the Shared Contract (`lib/contracts/task_contract.dart`)
```dart
import 'package:bloom_js_native/bloom_js_native.dart';

class Task {
  final String id;
  final String title;
  final bool completed;

  Task({required this.id, required this.title, this.completed = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'completed': completed};

  factory Task.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: map['completed'] as bool? ?? false,
    );
  }
}

class CreateTaskInput {
  final String title;
  CreateTaskInput({required this.title});
  Map<String, dynamic> toJson() => {'title': title};
  factory CreateTaskInput.fromJson(dynamic json) =>
      CreateTaskInput(title: (json as Map)['title'] as String? ?? '');
}

const getTaskContract = BloomRpcContract<void, Task>.get(
  '/tasks/:id',
  decodeOutput: Task.fromJson,
);

const createTaskContract = BloomRpcContract<CreateTaskInput, Task>.post(
  '/tasks',
  encodeInput: (input) => input.toJson(),
  decodeInput: CreateTaskInput.fromJson,
  encodeOutput: (task) => task.toJson(),
  decodeOutput: Task.fromJson,
);
```

#### 2. Implement and Mount on Server (`bin/server.dart`)
```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_server/bloom_server.dart';

void main() async {
  final rpcRouter = BloomRpcRouter();

  // Bind server implementation
  rpcRouter.bind(getTaskContract, (ctx, _) async {
    final id = ctx.pathParams['id']!;
    return Task(id: id, title: 'Server-rendered task', completed: true);
  });

  rpcRouter.bind(createTaskContract, (ctx, input) async {
    if (input.title.trim().isEmpty) {
      throw const BloomRpcValidationErrors(
        fieldErrors: {'title': ['Title is required']},
      );
    }
    return Task(id: 'task-101', title: input.title);
  });

  final apiRouter = BloomApiRouter();
  apiRouter.mountRpc(rpcRouter, basePath: '/api/rpc');

  await apiRouter.serve(port: 8090);
}
```

#### 3. Call from Client UI (`lib/main.dart`)
```dart
import 'package:bloom_js_native/bloom_js_native.dart';

final rpcClient = BloomRpcClient(baseUrl: '/api/rpc');

// Reactive query binding
final taskQuery = rpcQuery<void, Task>(
  rpcClient,
  getTaskContract,
  null,
  pathParams: {'id': 'task-101'},
);

BloomNode taskWidget() {
  return Div(
    className: 'task-card',
    children: [
      Live(() => switch (taskQuery.status.value) {
        QueryStatus.loading => P(text: 'Loading task...'),
        QueryStatus.error => P(text: 'Error loading task'),
        QueryStatus.success => H2(text: taskQuery.data.value?.title ?? ''),
        QueryStatus.idle => P(text: 'Idle'),
      }),
    ],
  );
}
```

---

### How do I safely use environment variables without leaking secrets?
Client-side web bundles (`main.js` / WebAssembly) are downloaded to the user's browser, meaning **any variable compiled into the client bundle is completely public and visible to anyone who inspects the network or source code**.

To prevent accidental exposure of private secrets (database passwords, private API keys, payment gateway secret tokens):

1. **The `BLOOM_PUBLIC_` Rule**: Only variables with the prefix `BLOOM_PUBLIC_` can be accessed in browser client code or injected during `bloom build web`.
2. **Build-Time Security Gate**: The Bloom compiler scans all injected environment files during `bloom build web`. If any variable lacks the `BLOOM_PUBLIC_` prefix, the build **fails immediately with an error** naming the offending key.
3. **Server Secrets**: Keep non-public variables in your server environment or `.env` files read exclusively by `bin/server.dart`.

```ini
# .env.production

# Client-public variables injected into web bundle
BLOOM_PUBLIC_API_URL=https://api.example.com
BLOOM_PUBLIC_APP_TITLE="Bloom Production"

# Server-only secrets: Used only in bin/server.dart; never injected into browser bundle
DATABASE_URL=postgres://user:password@db.internal:5432/app
STRIPE_SECRET_KEY=sk_live_secret12345
```

Reading public variables in Dart:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  // Read public variables safely
  final apiUrl = BloomEnv.get('BLOOM_PUBLIC_API_URL', defaultValue: '/api');

  // Check if a key is public
  final isPublic = BloomEnv.isPublic('BLOOM_PUBLIC_API_URL'); // true

  // Get all public variables as an unmodifiable map
  final publicMap = BloomEnv.publicVariables;
}
```

---

## 19. UI Component Primitives

Bloom provides a comprehensive, 47-component UI primitives library (`package:bloom_js_native/bloom_js_native.dart`) inspired by modern design systems like shadcn/ui. Every primitive is built on pure Dart AST descriptors (`BloomNode`), styled with CSS custom property design tokens (`var(--primary)`, `var(--card)`, etc.), and adheres to strict accessibility semantics (`role`, `aria-*`).

Because components are pure `BloomNode` descriptor trees, they render identically during Server-Side Rendering (SSR) and in client browsers. All UI primitives are exported directly from `package:bloom_js_native/bloom_js_native.dart`.

### State Ownership Model in Bloom UI
Before using the components, understand how state is partitioned across three categories of primitives:
1. **Plain Stateless Descriptors**: Most components (e.g. `button`, `badge`, `card`, `table`, `formField`, `skeleton`, `aspectRatio`, `hoverCard`, `tooltip`) are pure descriptor functions that transform parameters into immutable `BloomNode` AST trees.
2. **Components with Internal Local Signals**: Components like `accordion()`, `popover()`, `dropdownMenu()`, `contextMenu()`, and `resizablePanels()` manage their own private reactive state (such as open/collapsed flags or split ratios) using internal signals. The caller does **not** need to create or pass a `Signal`.
3. **Components Requiring Caller-Owned State**: Components like `tabs()`, `calendar()`, `radioGroup()`, `switchToggle()`, `slider()`, `inputOtp()`, `toggle()`, `toggleGroupSingle()`, and `toggleGroupMultiple()` require the caller to own and pass reactive state (`value`, `onChange`, `activeKey`). Wrap these in `Live(() => ...)` boundaries so the UI automatically updates when your signals change.
4. **Global Overlay Viewports**: Overlays such as `dialog` (`openDialog`), `sheet` (`openSheet`), `drawer` (`openDrawer`), `command` (`openCommandPalette`), and `sonner` (`showToast`) use global signals and viewport components (`dialogViewport()`, `sheetViewport()`, `drawerViewport()`, `commandViewport()`, `toastViewport()`). Mount these viewports once near your application root.

---

### How do I configure Bloom UI design tokens and customize the theme?
Bloom UI primitives use CSS custom properties for theming (`--primary`, `--bg`, `--card`, `--border`, `--text`, `--radius-md`, etc.). The framework exports `uiTokensCss`, which provides a complete slate/indigo light and dark theme (with automatic `@media (prefers-color-scheme: dark)` and `[data-theme="dark"]` support).

Consuming applications can inject `uiTokensCss` into their root document or override specific tokens in their own global CSS.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Inject default Bloom UI design tokens into your root HTML template
String renderRootDocument(BloomNode bodyContent) {
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>$uiTokensCss</style>
  <style>
    /* Custom brand override */
    :root {
      --primary: #4f46e5;
      --radius: 10px;
    }
  </style>
</head>
<body class="bg-[var(--bg)] text-[var(--text)] antialiased">
  ${renderToHtml(bodyContent)}
</body>
</html>
''';
}
```

---

### How do I define my own design tokens as Dart, not by hand-editing `web/index.html`?

Keep `web/index.html` minimal (meta tags, fonts, the `main.js` script tag — see Section 20) and define your token palette as Dart instead: a `const String` of raw CSS in its own file, injected into the live DOM via the `Style` node (`StyleNode` — Section: framework core), which both `mount()` and `renderToHtml()` render correctly (a real `<style>` element in the browser, inlined verbatim under SSR). This keeps your tokens colocated with the rest of your Dart source, version-controlled and reviewable like any other code, and avoids growing `web/index.html` into a second, disconnected styling surface.

```dart
// lib/design/tokens.dart
const designTokensCss = r'''
:root {
  /* Neutrals */
  --n-0: #ffffff;
  --n-50: #fafaf9;
  --n-900: #1c1917;
  --n-950: #0c0a09;

  /* Brand — name your own palette here, don't reuse Bloom UI's default
     indigo scale unless you actually want the default look */
  --brand-500: #14b8a6;
  --brand-600: #0d9488;
  --brand-700: #0f766e;

  /* Semantic surfaces — components read these, not the raw --n-*/--brand-*
     scales directly, so retheming means editing only this block */
  --bg: var(--n-0);
  --text: var(--n-900);
  --border: #e7e5e4;
  --radius-md: 10px;
  --font-sans: 'Inter', system-ui, sans-serif;
  color-scheme: light;
}

@media (prefers-color-scheme: dark) {
  :root { --bg: var(--n-950); --text: var(--n-50); color-scheme: dark; }
}
[data-theme="dark"] { --bg: var(--n-950); --text: var(--n-50); }
[data-theme="light"] { --bg: var(--n-0); --text: var(--n-900); }

html { font-family: var(--font-sans); background: var(--bg); color: var(--text); }
''';
```

Inject it once, as the first child returned by your app's root/shell component — not per-page, so it's emitted (and, under SSR, hydrated) exactly once regardless of route:

```dart
// lib/app.dart (or wherever your shell/layout component lives)
import 'package:bloom_js_native/bloom_js_native.dart';
import 'design/tokens.dart';

BloomNode appShell(BloomNode content) {
  return Fragment(children: [
    Style(designTokensCss),
    Div(
      className: 'min-h-screen bg-[var(--bg)] text-[var(--text)]',
      children: [content],
    ),
  ]);
}
```

Every UI primitive in Section 19 reads these same variable names (`var(--primary)`, `var(--radius)`, `var(--bg)`, ...) — if you're using the UI primitives library alongside your own tokens, either keep the variable names it expects (`--primary`, `--card`, `--radius-md`, etc. — see `uiTokensCss` in `lib/src/ui/tokens.dart` for the full set it reads) or accept that primitives will fall back to their own built-in defaults for any name you don't define. Never hardcode a color/radius literal in a `className` when a token already names that role — override the token in `tokens.dart` instead, so every component using it updates together. See Section 20 for the same rule as a one-line pre-flight check.

---

### How do I load web fonts without hand-writing `<link>` tags in `web/index.html`?

Don't add a Google Fonts CDN `<link>` (or `@import`) to `web/index.html` — it's an unpinned, un-vendored, render-blocking third-party network request on every page load, and it grows a file that should otherwise stay near-empty. Self-host instead:

```
bloom fonts optimize --family Inter --weight 400 --weight 700
```

This downloads the requested Google Font family/weights, self-hosts the `.woff2` files under `web/generated/fonts/`, and generates `web/generated/fonts/fonts.g.css` with `@font-face` rules plus a CLS-mitigation fallback face (a metric-compatible system font swapped in until the real face loads, sized to match — avoids the layout jump a bare `font-display: swap` causes).

Then reference the generated stylesheet the same way you reference design tokens — as a `BloomNode` from Dart, not a hand-written `<link>` in `web/index.html` — using `fontStylesheetLink()`:

```dart
// lib/app.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'design/tokens.dart';

BloomNode appShell(BloomNode content) {
  return Fragment(children: [
    Style(designTokensCss),
    fontStylesheetLink(), // defaults to /generated/fonts/fonts.g.css — matches bloom fonts optimize's output
    Div(
      className: 'min-h-screen bg-[var(--bg)] text-[var(--text)] font-sans',
      children: [content],
    ),
  ]);
}
```

If you generated the stylesheet somewhere other than the default path, pass it explicitly: `fontStylesheetLink(href: '/generated/fonts/fonts.g.css')`. Re-run `bloom fonts optimize` whenever you add a family/weight — it's a build step, not something `bloom js dev`/`bloom js build` runs automatically.

---

### How do I render vector SVG icons and combine dynamic classes?
Bloom avoids toy emojis and external icon font dependencies by providing clean, built-in vector SVG icons via `uiIcon()` and `iconSvgString()`. Class names can be dynamically merged using `cn()`, which strips null and false values.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode iconAndClassDemo({required bool isActive, required bool isPending}) {
  return Div(
    className: cn([
      'flex items-center gap-2 p-3 rounded-[var(--radius-md)] border select-none',
      isActive ? 'border-[var(--primary)] bg-[var(--primary)]/10' : 'border-[var(--border)] bg-[var(--card)]',
      isPending && 'opacity-60 pointer-events-none',
    ]),
    children: [
      uiIcon('search', className: 'w-4 h-4 text-[var(--primary)]'),
      Span(text: 'Search records'),
      if (isPending)
        uiIcon('spinner', className: 'w-4 h-4 animate-spin text-[var(--text-muted)] ml-auto')
      else
        uiIcon('chevron-right', className: 'w-4 h-4 text-[var(--text-muted)] ml-auto'),
    ],
  );
}
```

---

### How do I use buttons with variants, sizes, loading states, and links?
The `button()` primitive supports six stylistic variants (`ButtonVariant.primary`, `secondary`, `outline`, `ghost`, `destructive`, `link`), four sizes (`ButtonSize.sm`, `md`, `lg`, `icon`), built-in icon integration, and automatic link rendering when `href` is supplied.

You can also use `buttonClasses()` directly if you need to apply the button style rules to custom elements.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buttonDemo(Signal<bool> isSaving) {
  return Div(
    className: 'flex items-center gap-3 flex-wrap',
    children: [
      // Primary button with icon and event handler
      button(
        text: 'Save Changes',
        icon: 'check',
        variant: ButtonVariant.primary,
        size: ButtonSize.md,
        onClick: (_) => print('Saved!'),
      ),
      // Destructive button
      button(
        text: 'Delete',
        icon: 'x',
        variant: ButtonVariant.destructive,
        size: ButtonSize.sm,
      ),
      // Ghost button
      button(
        text: 'Cancel',
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
      ),
      // Link button that renders an <a> tag
      button(
        text: 'Documentation',
        href: '/docs',
        variant: ButtonVariant.link,
      ),
      // Reactive button reflecting loading state
      Live(() => button(
        text: isSaving.value ? 'Saving...' : 'Submit',
        loading: isSaving.value,
        variant: ButtonVariant.secondary,
        onClick: (_) => isSaving.value = true,
      )),
    ],
  );
}
```

---

### How do I display status badges with variants and dismiss actions?
The `badge()` primitive provides compact status indicators supporting seven visual variants (`BadgeVariant.defaultVariant`, `secondary`, `destructive`, `outline`, `success`, `warning`, `info`), optional icons, and interactive dismiss buttons (`onDismiss`).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode badgeDemo(Signal<List<String>> tags) {
  return Div(
    className: 'flex items-center gap-2 flex-wrap',
    children: [
      badge(
        label: 'Production',
        variant: BadgeVariant.success,
        icon: 'check',
      ),
      badge(
        label: 'Requires Attention',
        variant: BadgeVariant.warning,
        icon: 'alert',
      ),
      badge(
        label: 'Archived',
        variant: BadgeVariant.outline,
      ),
      // Reactive dismissible badges
      Live(() => Fragment(
        children: tags.value.map((tag) {
          return badge(
            label: tag,
            variant: BadgeVariant.secondary,
            onDismiss: () {
              tags.value = tags.value.where((t) => t != tag).toList();
            },
          );
        }).toList(),
      )),
    ],
  );
}
```

---

### How do I render user avatars and overlapping avatar groups?
The `avatar()` primitive displays user profile images with automatic fallback text (initials) when an image is missing or loading. It also supports corner status `badge` nodes. Use `avatarGroup()` to neatly overlap multiple avatars.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode avatarDemo() {
  return Div(
    className: 'flex items-center gap-6',
    children: [
      // Avatar with image and online status indicator badge
      avatar(
        src: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=96',
        alt: 'Sarah Connor',
        size: AvatarSize.lg,
        badge: Span(className: 'w-2.5 h-2.5 rounded-full bg-emerald-500'),
      ),
      // Fallback initials avatar
      avatar(
        fallbackText: 'SC',
        size: AvatarSize.md,
      ),
      // Overlapping avatar group
      avatarGroup(
        children: [
          avatar(fallbackText: 'AL', size: AvatarSize.md),
          avatar(fallbackText: 'BK', size: AvatarSize.md),
          avatar(fallbackText: 'CM', size: AvatarSize.md),
          avatar(fallbackText: '+5', size: AvatarSize.md),
        ],
      ),
    ],
  );
}
```

---

### How do I display skeleton loaders, separators, and aspect ratios?
Use `skeleton()` for pulse-animated loading placeholders, `separator()` for horizontal and vertical content dividers, and `aspectRatio()` to lock children (images, video embeds, charts) to fixed proportions (e.g. `16 / 9`, `4 / 3`, `1 / 1`).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode displayHelpersDemo() {
  return Div(
    className: 'flex flex-col gap-4 max-w-sm',
    children: [
      // 16:9 media container
      aspectRatio(
        ratio: 16 / 9,
        child: skeleton(extraClassName: 'w-full h-full'),
      ),
      // Horizontal divider
      separator(),
      // Skeleton card placeholder
      Div(
        className: 'flex items-center gap-3',
        children: [
          skeleton(extraClassName: 'w-10 h-10 rounded-full'),
          Div(
            className: 'flex flex-col gap-2 flex-1',
            children: [
              skeleton(extraClassName: 'h-4 w-3/4'),
              skeleton(extraClassName: 'h-3 w-1/2'),
            ],
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I structure content cards with headers, bodies, and footers?
The `card()` primitive provides a composite container decomposed into `cardHeader()`, `cardTitle()`, `cardDescription()`, `cardContent()`, and `cardFooter()`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode cardDemo() {
  return card(
    extraClassName: 'max-w-md',
    children: [
      cardHeader(
        children: [
          cardTitle(text: 'Deploy Project'),
          cardDescription(text: 'Deploy your new Bloom application to edge infrastructure.'),
        ],
      ),
      cardContent(
        children: [
          P(
            className: 'text-sm text-[var(--text-muted)] leading-relaxed',
            text: 'Your application will be built as a native WebAssembly bundle with SSR enabled.',
          ),
        ],
      ),
      cardFooter(
        extraClassName: 'justify-end gap-2',
        children: [
          button(text: 'Cancel', variant: ButtonVariant.ghost),
          button(text: 'Deploy Now', variant: ButtonVariant.primary),
        ],
      ),
    ],
  );
}
```

---

### How do I render semantic, scrollable data tables?
The `table()` component family (`table`, `tableHeader`, `tableBody`, `tableFooter`, `tableRow`, `tableHead`, `tableCell`, `tableCaption`) builds fully responsive HTML `<table>` elements enclosed in horizontal overflow viewports.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode tableDemo() {
  final invoices = [
    (id: 'INV-001', status: 'Paid', method: 'Credit Card', amount: '\$250.00'),
    (id: 'INV-002', status: 'Pending', method: 'PayPal', amount: '\$150.00'),
    (id: 'INV-003', status: 'Unpaid', method: 'Bank Transfer', amount: '\$450.00'),
  ];

  return table(
    children: [
      tableCaption(text: 'A list of your recent invoices.'),
      tableHeader(
        children: [
          tableRow(
            children: [
              tableHead(text: 'Invoice'),
              tableHead(text: 'Status'),
              tableHead(text: 'Method'),
              tableHead(text: 'Amount'),
            ],
          ),
        ],
      ),
      tableBody(
        children: invoices.map((inv) {
          return tableRow(
            children: [
              tableCell(text: inv.id),
              tableCell(
                children: [
                  badge(
                    label: inv.status,
                    variant: inv.status == 'Paid'
                        ? BadgeVariant.success
                        : inv.status == 'Pending'
                            ? BadgeVariant.warning
                            : BadgeVariant.destructive,
                  ),
                ],
              ),
              tableCell(text: inv.method),
              tableCell(text: inv.amount),
            ],
          );
        }).toList(),
      ),
      tableFooter(
        children: [
          tableRow(
            children: [
              tableCell(text: 'Total Invoiced', colSpan: 3),
              tableCell(text: '\$850.00'),
            ],
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I display breadcrumb navigation paths?
The `breadcrumb()` primitive renders an accessible `<nav aria-label="Breadcrumb">` hierarchy with chevron separators, linking ancestor pages and styling the active leaf item.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode breadcrumbDemo() {
  return breadcrumb([
    (label: 'Dashboard', href: '/dashboard'),
    (label: 'Projects', href: '/dashboard/projects'),
    (label: 'Bloom Web', href: '/dashboard/projects/bloom-web'),
    (label: 'Settings', href: null), // Current active page
  ]);
}
```

---

### How do I build text inputs, textareas, and input groups?
Use `textInput()` for single-line text/password/email fields (supporting leading/trailing icons via `prefixNode`/`suffixNode` and error styling via `hasError`), `textarea()` for multi-line inputs, and `inputGroup()` with `inputGroupAddon()` / `inputGroupText()` for compound inputs.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode textInputsDemo(Signal<String> query, Signal<String> notes) {
  return Div(
    className: 'flex flex-col gap-4 max-w-md',
    children: [
      // Text input with search icon prefix
      textInput(
        id: 'search-input',
        placeholder: 'Search documentation...',
        prefixNode: uiIcon('search', className: 'w-4 h-4'),
        onInput: (e) => query.value = e.value ?? '',
      ),
      // Compound input group with prefix and suffix addons
      inputGroup(
        children: [
          inputGroupAddon(
            align: 'left',
            children: [inputGroupText(text: 'https://')],
          ),
          textInput(
            id: 'subdomain-input',
            placeholder: 'my-workspace',
            extraClassName: 'border-0 rounded-none shadow-none focus:ring-0',
          ),
          inputGroupAddon(
            align: 'right',
            children: [inputGroupText(text: '.bloom.app')],
          ),
        ],
      ),
      // Multi-line textarea
      textarea(
        id: 'notes-input',
        placeholder: 'Enter additional deployment notes...',
        rows: 4,
        onInput: (e) => notes.value = e.value ?? '',
      ),
    ],
  );
}
```

---

### How do I structure forms with labels, fieldsets, and validation messages?
Use `label()` for standalone accessible form labels, `formField()` to bind a control with label, required asterisk, help text, and error messages, `fieldSet()` for semantic fieldsets with legends, and `fieldGroup()` to stack fields.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode formStructureDemo({
  required Signal<String> email,
  required Signal<String?> emailError,
}) {
  return fieldSet(
    legend: 'Account Settings',
    children: [
      fieldGroup(
        children: [
          Live(() => formField(
            id: 'email-input',
            label: 'Email Address',
            required: true,
            error: emailError.value,
            help: 'We will send transaction receipts to this address.',
            control: textInput(
              id: 'email-input',
              type: 'email',
              placeholder: 'alex@example.com',
              hasError: emailError.value != null,
              onInput: (e) {
                email.value = e.value ?? '';
                emailError.value = null;
              },
            ),
          )),
        ],
      ),
    ],
  );
}
```

---

### How do I handle checkboxes, toggle switches, and radio groups?
The `checkbox()`, `switchToggle()`, and `radioGroup()` primitives are controlled components where the caller passes current values and change handlers. Wrap their invocations in `Live(() => ...)` to re-render reactively.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode selectionControlsDemo({
  required Signal<bool> agreeTerms,
  required Signal<bool> enableDarkTheme,
  required Signal<String> plan,
}) {
  return Div(
    className: 'flex flex-col gap-5 max-w-sm',
    children: [
      // Checkbox with label
      Live(() => checkbox(
        id: 'terms-check',
        label: 'I accept the terms of service',
        checked: agreeTerms.value,
        onCheckedChange: (checked) => agreeTerms.value = checked,
      )),
      // Toggle Switch
      Live(() => Div(
        className: 'flex items-center justify-between',
        children: [
          label(text: 'Dark Mode', htmlFor: 'dark-theme-switch'),
          switchToggle(
            id: 'dark-theme-switch',
            checked: enableDarkTheme.value,
            onChange: (checked) => enableDarkTheme.value = checked,
          ),
        ],
      )),
      // Radio Group
      Live(() => radioGroup(
        name: 'pricing-tier',
        value: plan.value,
        options: [
          (value: 'hobby', label: 'Hobby (Free)'),
          (value: 'pro', label: 'Pro (\$20/mo)'),
          (value: 'enterprise', label: 'Enterprise (Custom)'),
        ],
        onChange: (val) => plan.value = val,
      )),
    ],
  );
}
```

---

### How do I use select dropdowns and range sliders?
Use `selectInput()` for styled native `<select>` dropdowns and `slider()` for accessible range slider inputs. Both are controlled components that bind directly to signals inside `Live()` blocks.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode selectAndSliderDemo({
  required Signal<String> region,
  required Signal<double> memoryLimit,
}) {
  return Div(
    className: 'flex flex-col gap-4 max-w-sm',
    children: [
      // Styled select dropdown
      Live(() => selectInput(
        id: 'region-select',
        value: region.value,
        placeholder: 'Select deployment region...',
        options: [
          (value: 'us-east', label: 'US East (N. Virginia)'),
          (value: 'eu-west', label: 'EU West (Frankfurt)'),
          (value: 'ap-southeast', label: 'AP Southeast (Singapore)'),
        ],
        onValueChange: (val) => region.value = val,
      )),
      // Range slider with readout
      Live(() => Div(
        className: 'flex flex-col gap-2',
        children: [
          Div(
            className: 'flex justify-between text-xs text-[var(--text-muted)]',
            children: [
              Span(text: 'Memory Allocation'),
              Span(text: '${memoryLimit.value.round()} MB'),
            ],
          ),
          slider(
            value: memoryLimit.value,
            min: 128,
            max: 2048,
            step: 128,
            onChange: (val) => memoryLimit.value = val,
          ),
        ],
      )),
    ],
  );
}
```

---

### How do I build one-time password (OTP) / PIN inputs?
The `inputOtp()` primitive creates individual segmented numeric input slots with automatic backspace navigation and character advance.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode otpVerificationDemo(Signal<String> pin) {
  return Div(
    className: 'flex flex-col items-center gap-3 p-4',
    children: [
      P(
        className: 'text-xs text-[var(--text-muted)]',
        text: 'Enter your 6-digit authentication PIN:',
      ),
      Live(() => inputOtp(
        length: 6,
        value: pin.value,
        onChange: (val) {
          pin.value = val;
          if (val.length == 6) {
            print('PIN complete: $val');
          }
        },
      )),
    ],
  );
}
```

---

### How do I trigger modal dialogs and alert confirmations?
Modal dialogs in Bloom use a decoupled viewport architecture: mount `dialogViewport()` once near your application root, and imperatively trigger modals anywhere in your codebase using `openDialog()`, `openConfirmDialog()`, or `openAlertDialog()`.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Mount dialogViewport() once at the root of your app
BloomNode appRootWithDialogs() {
  return Div(
    children: [
      dialogViewport(), // Subscribes to global activeDialog signal
      Div(
        className: 'flex gap-3',
        children: [
          button(
            text: 'Delete Cluster',
            variant: ButtonVariant.destructive,
            onClick: (_) {
              openAlertDialog(
                title: 'Delete Kubernetes Cluster?',
                description: 'This action is irreversible and will terminate all running pods.',
                confirmLabel: 'Yes, Delete Cluster',
                cancelLabel: 'Cancel',
                destructive: true,
                onConfirm: () => print('Cluster deleted'),
              );
            },
          ),
          button(
            text: 'Invite Member',
            variant: ButtonVariant.outline,
            onClick: (_) {
              openDialog(
                title: 'Invite Team Member',
                description: 'Enter an email to send an invite link.',
                body: textInput(id: 'invite-email', placeholder: 'colleague@company.com'),
                confirmLabel: 'Send Invitation',
                cancelLabel: 'Cancel',
                onConfirm: () => print('Invitation sent'),
              );
            },
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I open slide-over sheets and mobile bottom drawers?
Slide-over panels and mobile drawers use `openSheet()` / `closeSheet()` and `openDrawer()` / `closeDrawer()`. Mount `sheetViewport()` (or its alias `drawerViewport()`) once at the application root. Sheets support `'right'`, `'left'`, `'top'`, and `'bottom'` docking.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Mount sheetViewport() once at application root
BloomNode appRootWithSheets() {
  return Div(
    children: [
      sheetViewport(), // Subscribes to global activeSheet signal
      Div(
        className: 'flex gap-3',
        children: [
          button(
            text: 'Open Settings Panel',
            variant: ButtonVariant.secondary,
            onClick: (_) {
              openSheet(
                title: 'Project Settings',
                description: 'Adjust environment variables and build pipelines.',
                side: 'right', // 'right' | 'left' | 'top' | 'bottom'
                body: P(text: 'Settings panel body content...'),
              );
            },
          ),
          button(
            text: 'Open Bottom Drawer',
            variant: ButtonVariant.outline,
            onClick: (_) {
              openDrawer(
                title: 'Quick Actions',
                body: P(text: 'Mobile drawer content...'),
              );
            },
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I use popovers, hover cards, and tooltips?
- `popover()` wraps a trigger and floating content card, managing its own internal `isOpen` signal and dismiss backdrop.
- `hoverCard()` provides pure-CSS preview cards on hover/focus.
- `tooltip()` provides pure-CSS hover/focus tooltips without JavaScript listeners.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode overlaysDemo() {
  return Div(
    className: 'flex items-center gap-6',
    children: [
      // Popover with internal click-toggle and backdrop state
      popover(
        align: 'left',
        trigger: button(text: 'Filter', icon: 'chevron-down', variant: ButtonVariant.outline),
        content: Div(
          className: 'flex flex-col gap-2 w-48',
          children: [
            Span(className: 'font-semibold text-xs', text: 'Status Filter'),
            checkbox(id: 'f-active', label: 'Active'),
            checkbox(id: 'f-paused', label: 'Paused'),
          ],
        ),
      ),
      // Pure-CSS Hover Card preview
      hoverCard(
        side: 'bottom',
        trigger: Span(className: 'underline font-medium cursor-pointer', text: '@bloom_framework'),
        content: Div(
          className: 'flex flex-col gap-1',
          children: [
            H4(className: 'font-semibold text-xs', text: 'Bloom Framework'),
            P(className: 'text-xs text-[var(--text-muted)]', text: 'Pure Dart web UI compiler with signals and SSR.'),
          ],
        ),
      ),
      // Pure-CSS Tooltip
      tooltip(
        label: 'Copy commit SHA',
        side: 'top',
        child: button(text: 'Copy SHA', variant: ButtonVariant.ghost, size: ButtonSize.sm),
      ),
    ],
  );
}
```

---

### How do I create dropdown menus and right-click context menus?
Both `dropdownMenu()` and `contextMenu()` take a list of `MenuItemConfig` items and manage their own internal open state and backdrop dismissal. `contextMenu()` captures the browser `contextmenu` event and positions the menu at pointer coordinates.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode menusDemo() {
  final menuItems = [
    MenuItemConfig(
      label: 'Edit Configuration',
      icon: 'search',
      onClick: () => print('Editing...'),
    ),
    const MenuItemConfig(
      label: 'Documentation',
      href: '/docs',
    ),
    const MenuItemConfig(
      label: 'Delete Record',
      icon: 'x',
      destructive: true,
    ),
  ];

  return Div(
    className: 'flex items-center gap-6',
    children: [
      // Dropdown menu on button trigger
      dropdownMenu(
        trigger: button(text: 'Actions', icon: 'chevron-down', variant: ButtonVariant.outline),
        items: menuItems,
        align: 'right',
      ),
      // Context menu on target surface
      contextMenu(
        items: menuItems,
        child: Div(
          className: 'p-6 border border-dashed border-[var(--border)] rounded-[var(--radius-md)] text-xs text-[var(--text-muted)] select-none',
          text: 'Right-click inside this card for context actions',
        ),
      ),
    ],
  );
}
```

---

### How do I implement tabbed views?
The `tabs()` primitive renders a segmented tablist and renders the active panel using a `content(key)` builder closure. Because the active tab is controlled, the caller owns the active key in a `Signal` and wraps `tabs()` in a `Live()` boundary.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode tabsDemo(Signal<String> activeTab) {
  return Live(() => tabs(
    items: [
      (key: 'overview', label: 'Overview'),
      (key: 'deployments', label: 'Deployments'),
      (key: 'settings', label: 'Settings'),
    ],
    activeKey: activeTab.value,
    onChange: (key) => activeTab.value = key,
    content: (key) => switch (key) {
      'overview' => P(text: 'Overview metrics, analytics, and service health.'),
      'deployments' => P(text: 'Recent deployment logs and rollout history.'),
      'settings' => P(text: 'Domain aliases and environment configuration.'),
      _ => const Fragment(children: []),
    },
  ));
}
```

---

### How do I build navigation bars and desktop menubars?
- `navigationMenu()` renders horizontal navigation bars with direct routes (`href`) and dropdown flyout panels (`content`).
- `menubar()` renders classic desktop application menu bars composed of multi-level dropdowns.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode navigationAndMenubarDemo() {
  return Div(
    className: 'flex flex-col gap-6',
    children: [
      // Horizontal navigation bar
      navigationMenu(
        items: [
          const NavMenuItem(label: 'Home', href: '/', active: true),
          NavMenuItem(
            label: 'Solutions',
            content: Div(
              className: 'w-60 p-3 flex flex-col gap-1',
              children: [
                H4(className: 'font-semibold text-xs', text: 'Edge SSR'),
                P(className: 'text-xs text-[var(--text-muted)]', text: 'Ultra-fast sub-millisecond server rendering.'),
              ],
            ),
          ),
          const NavMenuItem(label: 'Pricing', href: '/pricing'),
        ],
      ),
      // Desktop application menubar
      menubar(
        menus: [
          (
            label: 'File',
            items: [
              MenuItemConfig(label: 'New File', onClick: () => print('New File')),
              MenuItemConfig(label: 'Save Project', onClick: () => print('Saved')),
            ],
          ),
          (
            label: 'Edit',
            items: [
              MenuItemConfig(label: 'Undo', onClick: () => print('Undo')),
              MenuItemConfig(label: 'Redo', onClick: () => print('Redo')),
            ],
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I implement cursor-based pagination?
The `paginationBar()` component renders previous/next links and page position summaries using cursor navigation helpers (`nextPageHref`, `prevPageHref`). It manages cursor history directly via URL query parameters.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode paginationDemo({
  required String currentPath,
  required Map<String, String> queryParams,
  required int totalItems,
  required int pageSize,
  String? nextCursor,
}) {
  return paginationBar(
    currentPath: currentPath,
    currentQuery: queryParams,
    total: totalItems,
    itemCount: pageSize,
    nextCursor: nextCursor,
    pageSize: pageSize,
  );
}
```

---

### How do I display contextual alert banners?
The `alert()` primitive displays static inline banners across four semantic variants (`AlertVariant.info`, `AlertVariant.success`, `AlertVariant.warning`, `AlertVariant.destructive`) with support for custom icons and trailing action buttons.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode alertBannersDemo() {
  return Div(
    className: 'flex flex-col gap-3 max-w-lg',
    children: [
      alert(
        title: 'Update Available',
        description: 'A new version of Bloom JS Native is available.',
        variant: AlertVariant.info,
      ),
      alert(
        title: 'Build Succeeded',
        description: 'Your application was compiled and deployed in 420ms.',
        variant: AlertVariant.success,
      ),
      alert(
        title: 'Session Expired',
        description: 'Please sign in again to continue managing your resources.',
        variant: AlertVariant.destructive,
        action: button(text: 'Sign In', size: ButtonSize.sm, variant: ButtonVariant.destructive),
      ),
    ],
  );
}
```

---

### How do I show determinate linear and circular progress indicators?
Use `progress()` for linear horizontal progress bars and `circularProgress()` for smooth SVG-based radial progress gauges.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode progressIndicatorsDemo(Signal<double> uploadProgress) {
  return Div(
    className: 'flex flex-col gap-6 max-w-sm',
    children: [
      // Linear progress bar with percentage label
      Live(() => progress(
        value: uploadProgress.value,
        max: 100.0,
        label: 'Uploading bundle...',
        showValue: true,
      )),
      // Circular progress gauges
      Live(() => Div(
        className: 'flex items-center gap-6 justify-center',
        children: [
          circularProgress(
            value: uploadProgress.value,
            max: 100,
            size: 48,
            showValue: true,
            label: 'Upload',
          ),
          circularProgress(
            value: 85,
            size: 36,
            color: 'var(--success)',
            strokeWidth: 4,
          ),
        ],
      )),
    ],
  );
}
```

---

### How do I dispatch and display toast notifications (Sonner)?
Bloom UI provides a global toast notification system (Sonner-style). Mount `toastViewport()` once near your application root, and call `showToast()` or `dismissToast()` from any event handler or asynchronous workflow.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Mount toastViewport() once at application root
BloomNode rootAppWithToasts() {
  return Div(
    children: [
      toastViewport(), // Subscribes to global toastList signal
      Div(
        className: 'flex gap-2 flex-wrap',
        children: [
          button(
            text: 'Trigger Success Toast',
            variant: ButtonVariant.outline,
            onClick: (_) => showToast(
              'Database migration completed successfully.',
              variant: ToastVariant.success,
              actionLabel: 'View Logs',
              onAction: () => print('Viewing migration logs'),
            ),
          ),
          button(
            text: 'Trigger Error Toast',
            variant: ButtonVariant.destructive,
            onClick: (_) => showToast(
              'Could not connect to Redis cache.',
              variant: ToastVariant.error,
            ),
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I create collapsible accordions?
The `accordion()` primitive renders expandable FAQ-style disclosure sections. It manages its own internal `openIds` signal, so the caller does **not** need to create or pass a `Signal`. Use `allowMultiple: true` to permit multiple open sections, and `initialOpen` to specify initial active items.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Accordion manages its own open/close state internally
BloomNode accordionDemo() {
  return accordion(
    allowMultiple: false,
    initialOpen: {'faq-1'},
    items: [
      (
        id: 'faq-1',
        title: 'Is Bloom JS Native compatible with SSR?',
        content: P(text: 'Yes. All components compile to pure BloomNode AST descriptors that render to HTML in <1ms on the server.'),
      ),
      (
        id: 'faq-2',
        title: 'Does it require Flutter?',
        content: P(text: 'No. Bloom JS Native has zero Flutter dependencies and compiles directly to native JS and Wasm.'),
      ),
    ],
  );
}
```

---

### How do I build single and multi-select toggle button groups?
Use `toggle()` for two-state buttons (`aria-pressed`), `toggleGroupSingle<T>()` for single-choice option sets (like text alignment), and `toggleGroupMultiple<T>()` for multi-selection sets (like font styling).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode toggleGroupsDemo({
  required Signal<bool> isBold,
  required Signal<String> alignment,
  required Signal<Set<String>> formatting,
}) {
  return Div(
    className: 'flex items-center gap-4 flex-wrap',
    children: [
      // Single toggle button
      Live(() => toggle(
        pressed: isBold.value,
        onChange: (pressed) => isBold.value = pressed,
        variant: ToggleVariant.outline,
        child: Span(className: 'font-bold px-1', text: 'B'),
      )),
      // Single-select toggle group
      Live(() => toggleGroupSingle<String>(
        value: alignment.value,
        onChange: (val) => alignment.value = val,
        items: [
          (value: 'left', child: Span(text: 'Left'), ariaLabel: 'Align left'),
          (value: 'center', child: Span(text: 'Center'), ariaLabel: 'Align center'),
          (value: 'right', child: Span(text: 'Right'), ariaLabel: 'Align right'),
        ],
      )),
      // Multi-select toggle group
      Live(() => toggleGroupMultiple<String>(
        value: formatting.value,
        onChange: (val) => formatting.value = val,
        items: [
          (value: 'italic', child: Span(className: 'italic px-1', text: 'I'), ariaLabel: 'Italic'),
          (value: 'underline', child: Span(className: 'underline px-1', text: 'U'), ariaLabel: 'Underline'),
          (value: 'strike', child: Span(className: 'line-through px-1', text: 'S'), ariaLabel: 'Strikethrough'),
        ],
      )),
    ],
  );
}
```

---

### How do I implement a command palette (Cmd+K modal)?
Command palettes provide searchable, keyboard-navigable action lists. Mount `commandViewport()` once at the root of your application, and invoke `openCommandPalette()` or `openCommandPaletteDetailed()` to display the palette.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// Mount commandViewport() once at root
BloomNode rootAppWithCommandPalette() {
  return Div(
    children: [
      commandViewport(), // Subscribes to global activeCommandPalette signal
      button(
        text: 'Quick Commands (Cmd+K)',
        icon: 'search',
        variant: ButtonVariant.outline,
        onClick: (_) {
          openCommandPaletteDetailed(
            placeholder: 'Type a command or search...',
            items: [
              CommandItemConfig(
                label: 'Create Workspace',
                group: 'Actions',
                icon: 'plus',
                shortcut: '⌘N',
                onSelect: () => print('Creating workspace...'),
              ),
              CommandItemConfig(
                label: 'View Analytics',
                group: 'Navigation',
                icon: 'search',
                shortcut: '⌘G',
                onSelect: () => print('Opening analytics...'),
              ),
              CommandItemConfig(
                label: 'Sign Out',
                group: 'Account',
                icon: 'x',
                onSelect: () => print('Signing out...'),
              ),
            ],
          );
        },
      ),
    ],
  );
}
```

---

### How do I render an interactive calendar date picker?
The `calendar()` primitive renders a month-grid date selector. The caller owns both the displayed month and the selected date signals.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode calendarDemo({
  required Signal<DateTime> activeMonth,
  required Signal<DateTime?> selectedDate,
}) {
  return Live(() => calendar(
    month: activeMonth.value,
    selected: selectedDate.value,
    onSelect: (date) {
      selectedDate.value = date;
      print('Selected date: ${date.toIso8601String()}');
    },
    onMonthChange: (month) {
      activeMonth.value = month;
    },
  ));
}
```

---

### How do I render pure-SVG bar charts and sparklines?
Bloom includes lightweight, dependency-free SVG data visualization primitives:
- `barChart()`: Computes relative heights, bottom axis baselines, and labels for bar chart data points.
- `sparkline()`: Generates responsive polyline trend graphs from raw numeric series.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode dataChartsDemo() {
  final chartData = <ChartDataPoint>[
    (label: 'Mon', value: 120.0),
    (label: 'Tue', value: 240.0),
    (label: 'Wed', value: 180.0),
    (label: 'Thu', value: 320.0),
    (label: 'Fri', value: 290.0),
    (label: 'Sat', value: 150.0),
    (label: 'Sun', value: 90.0),
  ];

  return Div(
    className: 'flex flex-col gap-6 max-w-lg',
    children: [
      // Bar Chart
      barChart(
        data: chartData,
        height: 160,
        color: 'var(--primary)',
      ),
      // Sparkline trend indicator card
      Div(
        className: 'flex items-center justify-between p-3 border border-[var(--border)] rounded-[var(--radius-md)] bg-[var(--card)]',
        children: [
          Div(
            className: 'flex flex-col',
            children: [
              Span(className: 'text-xs text-[var(--text-muted)]', text: 'Throughput'),
              Span(className: 'text-lg font-semibold', text: '3,842 req/s'),
            ],
          ),
          sparkline(
            values: [10, 15, 12, 28, 24, 42, 35, 50, 48, 62],
            width: 120,
            height: 32,
            color: 'var(--success)',
          ),
        ],
      ),
    ],
  );
}
```

---

### How do I build resizable split-pane layouts and custom scroll areas?
- `resizablePanels()` divides two panes horizontally or vertically with an interactive separator handle.
- `scrollArea()` wraps scrollable content with customized, lightweight scrollbar styling without external JavaScript libraries.

> **SSR note**: `resizablePanels()` renders the initial split ratio during SSR. Live pointer drag resizing activates exclusively in browser builds.

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode splitLayoutDemo() {
  return Div(
    className: 'h-96 w-full border border-[var(--border)] rounded-[var(--radius-lg)] overflow-hidden',
    children: [
      resizablePanels(
        initialSplit: 0.3,
        minSplit: 0.15,
        maxSplit: 0.85,
        withHandle: true,
        first: scrollArea(
          maxHeight: 384,
          child: Div(
            className: 'p-4 flex flex-col gap-2',
            children: List.generate(25, (i) => P(className: 'text-xs', text: 'Sidebar item #$i')),
          ),
        ),
        second: scrollArea(
          maxHeight: 384,
          child: Div(
            className: 'p-4 flex flex-col gap-2',
            children: List.generate(25, (i) => P(className: 'text-xs', text: 'Main content line #$i')),
          ),
        ),
      ),
    ],
  );
}
```

---

### How do I link self-hosted optimized fonts?
The `fontStylesheetLink()` helper emits a `<link rel="stylesheet" href="...">` node pointing to self-hosted fonts optimized and generated by the Bloom CLI (`bloom fonts optimize`).

```dart
import 'package:bloom_js_native/bloom_js_native.dart';

// In server SSR or root HTML template generation:
String renderHtmlDocument(BloomNode rootNode) {
  final fontLink = renderToHtml(fontStylesheetLink());
  final appHtml = renderToHtml(rootNode);

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <style>$uiTokensCss</style>
  $fontLink
</head>
<body class="bg-[var(--bg)] text-[var(--text)]">
  <div id="app">$appHtml</div>
</body>
</html>
''';
}
```

---

## 20. Best Practices & Common Pitfalls Checklist

A consolidated reference of every mistake this framework's own gotchas invite. Each item links back to the section that explains it in depth — read this section last, as a pre-flight checklist before shipping a feature, not as a substitute for the recipes above.

### Reactivity

- **Reading a signal outside `Live`/`Show`/`ForEach` captures a one-time snapshot, not a subscription.** This is the #1 beginner bug — see Section 2. If a value doesn't update on screen after a signal changes, this is almost always why.
- **Update a list/map signal by reassigning `.value`, never by mutating the existing collection in place.** `todos.value.add(x)` does not notify subscribers because the identity of `.value` never changed; `todos.value = [...todos.value, x]` does. Every list-mutation example in this cookbook (Section 6, Section 7) reassigns for this reason — copy the pattern exactly, don't "simplify" it back to `.add()`/`.remove()`.
- **Always pass `key:` to `ForEach` for any list that can reorder, insert, or remove items** (Section 6). An unkeyed `ForEach` tears down and rebuilds every child DOM node on each update — visible as lost input focus, restarted CSS transitions, or flicker.
- **`Show` with no `fallback` renders nothing (an empty fragment) when `when()` is false** (Section 6) — not `null`-safe-navigation nothing, an actual empty slot. If you need placeholder content, pass `fallback` explicitly.

### Events

- **`BloomEvent.value` and `BloomEvent.checked` are both nullable (`String?`, `bool?`).** `value` is only populated for input-like elements (`<input>`, `<textarea>`, `<select>`); `checked` only for checkboxes/radios. Never write `e.value!` — use `e.value ?? ''` (see the `onInput` pattern throughout Section 4 and Section 7) or an explicit null check. A bare `!` here is a guaranteed runtime crash on any event Bloom didn't populate that field for.
- **`e.rawTarget` is `Object?` (not a typed DOM element)** and is `null` in VM test fixtures unless a test explicitly provides one — never assume it's non-null in code that also runs under `dart test`.

### The Two Entry Points (Section 1)

- `package:bloom_js_native/bloom_js_native.dart` — pure Dart, safe everywhere (SSR, VM tests, shared files). Never import `browser.dart` here.
- `package:bloom_js_native/browser.dart` — `mount()`, `mountToElement()`, `hydrate()`, `BloomRouterController`, Web Component interop. Only your client entry point (`lib/main.dart`) should import this.
- **Symptom of getting this backwards**: `Error: Method not found: 'mount'.` at compile time if you only imported the base package, or a broken/non-portable build if you leak `browser.dart` into code SSR or tests also load.

### SSR / Hydration (Section 2, Section 10)

- Under `renderToHtml()`, reactive builders inside `Live`/`Show`/`ForEach` run **exactly once, synchronously** — there is no re-render loop on the server.
- **These do nothing under SSR** — silently, with no error: event handlers (`onClick`, `onInput`, etc.), lifecycle hooks (`Mount.onMount`/`onUnmount`), `Ref`, client router listeners, and any signal `effect()`. Code that must run server-side (data fetching, redirects) belongs in loader/route-guard hooks (Section 8, Section 9), not in these.

### Disposal (Section 2)

Anything that attaches an external listener, DOM observer, or timer must be disposed when its owner is torn down — leaking it is a real, silent memory/listener leak in a long-lived SPA:
- `BloomMountHandle.unmount()` — tears down mounted DOM + nested effects.
- `BloomRouterController.dispose()` — `popstate` + intersection observers.
- `BloomVirtualizer.dispose()` — scroll/resize observers.
- `BloomIslandOrchestrator.dispose()` — island intersection/interaction triggers.
- `BloomController.onDispose()` — controller effects + registered cleanup callbacks.
- `BloomQuery.dispose()` / `BloomInfiniteQuery.dispose()` — cache invalidation subscriptions.

### Styling, Tokens, and Fonts (Section 3, Section 19)

- Keep `web/index.html` as close to empty as possible: `<meta>` tags, SEO/JSON-LD/`robots` content once you add those, and the `main.js` script tag. No design tokens, no font `<link>`s, no inline `<style>`/`<script>` logic — all of that is Dart-driven and belongs in `lib/`.
- Define design tokens as a `const String` of raw CSS in `lib/design/tokens.dart`, injected once via `Style(tokensCss)` as the first child of your app shell — not pasted into `web/index.html`. See Section 19's "How do I define my own design tokens as Dart" recipe.
- Load fonts with `bloom fonts optimize --family <name> --weight <n>` (self-hosts `.woff2`, generates `fonts.g.css` with a CLS-mitigation fallback) and inject the result with `fontStylesheetLink()` from Dart — never a Google Fonts CDN `<link>` in `web/index.html`. See Section 19's font recipe.
- Prefer `scopedCss()` for component-local styles — it produces class names that match bit-for-bit between SSR output and client hydration; hand-rolled unique class names risk a hydration mismatch.
- The UI primitives library (Section 19) is themed entirely through CSS custom properties (`uiTokensCss` — `--n-0`…`--n-950`, `--primary`, `--radius`, etc.). Override a token in your own `lib/design/tokens.dart`, not by overriding a component's generated classes directly — the components read the variables, not hardcoded colors.
- Merge conditional class names with `cn([...])` (filters `null`/`false`/empty/whitespace-only entries and joins with a single space) rather than string-interpolating ternaries — every UI primitive's `extraClassName`/`className` parameter is designed to compose with `cn()`.

### Project Structure (Section 3)

- One `BloomNode`-returning function per file once a component exceeds a couple of screens of code; file name matches function name.
- Shared `Signal<T>` instances live in `lib/state/`, exported as top-level `final`s — component-local signals stay local, don't promote them preemptively.
- Route builders live in `lib/routes/`, registered once in `lib/app.dart`'s `BloomRoute` list — don't inline route builders directly in `main.dart` past a couple of routes.

### Testing (Section 16)

- Test files run on the Dart VM (`dart test`), which has no DOM — never import `browser.dart` in a `test/*.dart` file. Test SSR-safe logic (signals, computed values, `renderToHtml()` output, route matching) directly; browser-only behavior (`mount()`, hydration, real DOM events) is not unit-testable and belongs behind manual/E2E verification instead.
