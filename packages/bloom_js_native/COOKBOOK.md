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

## 3. Getting Something on Screen

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

## 4. State and Reactivity

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

## 5. Lists and Conditionals

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

## 6. Forms

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

## 7. Data Fetching and Mutations

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

## 8. Routing

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

## 9. Server-Side Rendering (SSR) & Hydration

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

## 10. Styling

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

## 11. Interop and Web Components

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

---

## 12. Internationalization (i18n) and Images

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

## 13. Accessibility (a11y)

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

## 14. Performance and Scheduling

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

## 15. Testing

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

## 16. Error Handling

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

## 17. Backend-for-Frontend (BFF)

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
