// lib/src/templates/templates.dart
import '../utils/project.dart';

class BloomTemplates {
  /// Default `bloom.yaml` template
  static String bloomYaml({
    required String name,
    String version = '0.1.0',
    String description = 'A modern application built with Bloom',
    int androidMinSdk = 24,
    int androidTargetSdk = 34,
    String iosMinVersion = '15.0',
  }) {
    return '''# Bloom Application Manifest
# Schema versioning ensures backwards compatibility
schema: 1

name: $name
version: $version
description: "$description"

platforms:
  android:
    min_sdk: $androidMinSdk
    target_sdk: $androidTargetSdk
  ios:
    minimum_version: "$iosMinVersion"
  web:
    title: "$name"

features:
  routing: true
  state: true
  data: false
  native: false

environment:
  files:
    - .env
    - .env.local

plugins: []
''';
  }

  /// Default `.env` template
  static String dotEnv({required String name}) {
    return '''# Application Environment Variables
APP_NAME=$name
APP_ENV=development
API_URL=http://localhost:8080/api
LOG_LEVEL=debug
''';
  }

  /// Default `.env.example` template
  static String dotEnvExample() {
    return '''# Example Environment Configuration
APP_NAME=MyApp
APP_ENV=development
API_URL=https://api.example.com
LOG_LEVEL=info
''';
  }

  /// Default `analysis_options.yaml` template
  static String analysisOptions() {
    return '''include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    file_names: ignore
''';
  }

  /// Default `lib/main.dart`
  static String mainDart({required String projectName}) {
    return '''// lib/main.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/boot.dart';
import 'app/routes.g.dart';

Future<void> main() async {
  // Initialize Bloom runtime, environment, and dependency injection
  await Bloom.boot(
    bootstrapper: const AppBootstrapper(),
  );

  runApp(
    BloomApp(
      title: Bloom.config.name,
      routerConfig: appRouter,
    ),
  );
}
''';
  }

  /// Default `lib/app/boot.dart`
  static String bootDart() {
    return '''// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';

/// AppBootstrapper executes during the `Bloom.boot()` sequence
/// before the widget tree mounts. Use this to register DI services and initialize storage.
class AppBootstrapper extends BloomBootstrapper {
  const AppBootstrapper();

  @override
  Future<void> onBoot(BloomContainer container) async {
    logger.info('Initializing application dependencies...');

    // Example DI registration:
    // container.provideSingleton<AuthService>(() => AuthService());
  }
}
''';
  }

  /// Default `lib/routes/index.dart`
  static String indexRoute({required String projectName}) {
    return '''// lib/routes/index.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class IndexRoute extends BloomRoute {
  const IndexRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);

    return Scaffold(
      appBar: AppBar(
        title: Text(Bloom.config.name),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BloomLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'Welcome to Bloom',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Environment: \${BloomEnv.get('APP_ENV', defaultValue: 'local')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 32),
            Watch((context) {
              return Text(
                'Clicks: \${count.value}',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => count.value++,
              icon: const Icon(Icons.add),
              label: const Text('Increment Signal'),
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  /// Scaffolds a new page/route
  static String genericRoute({
    required String className,
    required String routePath,
  }) {
    return '''// lib/routes/$routePath.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class $className extends BloomRoute {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$className'),
      ),
      body: const Center(
        child: Text('$className Screen'),
      ),
    );
  }
}
''';
  }

  /// Scaffolds a new BloomController
  static String controller({
    required String className,
    required String featureName,
  }) {
    return '''// lib/features/$featureName/controllers/\${featureName}_controller.dart
import 'package:bloom_framework/bloom.dart';

class $className extends BloomController {
  final count = signal(0);
  late final isEven = computed(() => count.value.isEven);

  void increment() => count.value++;
  void decrement() => count.value--;
  void reset() => count.value = 0;

  @override
  void onInit() {
    super.onInit();
    logger.info('$className initialized');
  }
}
''';
  }

  /// Scaffolds a `test/features/<feature>/<feature>_controller_test.dart`
  /// for a controller generated by `bloom generate controller`.
  static String controllerTest({
    required String className,
    required String featureName,
    required String projectName,
  }) {
    return '''// test/features/$featureName/${featureName}_controller_test.dart
import 'package:$projectName/features/$featureName/controllers/${featureName}_controller.dart';
import 'package:test/test.dart';

void main() {
  group('$className', () {
    test('starts at 0', () {
      final controller = $className();
      expect(controller.count.value, 0);
    });

    test('increment() increases count by 1', () {
      final controller = $className();
      controller.increment();
      expect(controller.count.value, 1);
    });

    test('decrement() decreases count by 1', () {
      final controller = $className();
      controller.decrement();
      expect(controller.count.value, -1);
    });

    test('reset() sets count back to 0', () {
      final controller = $className();
      controller.increment();
      controller.increment();
      controller.reset();
      expect(controller.count.value, 0);
    });
  });
}
''';
  }

  /// Scaffolds a new Model
  static String model({required String className}) {
    return '''// lib/models/\${className.toLowerCase()}.dart

class $className {
  final String id;
  final String title;
  final DateTime createdAt;

  const $className({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory $className.fromJson(Map<String, dynamic> json) {
    return $className(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
''';
  }

  /// Scaffolds a new Service
  static String service({required String className}) {
    return '''// lib/services/\${className.toLowerCase()}.dart
import 'package:bloom_framework/bloom.dart';

class $className {
  Future<void> initialize() async {
    logger.info('$className initialized');
  }
}
''';
  }

  /// Generates `lib/app/routes.g.dart` from discovered routes
  static String generatedRouter({
    required String projectName,
    required List<DiscoveredRoute> routes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by Bloom CLI');
    buffer.writeln(
        '// ignore_for_file: depend_on_referenced_packages, unused_import, file_names');
    buffer.writeln('');
    buffer.writeln("import 'package:bloom_framework/bloom.dart';");
    buffer.writeln('');

    // Imports for all routes
    for (final r in routes) {
      buffer.writeln("import '../routes/${r.relativeFilePath}';");
    }
    buffer.writeln('');

    buffer.writeln('final GoRouter appRouter = BloomRouter.create(');
    buffer.writeln("  initialLocation: '/',");
    buffer.writeln('  routes: [');

    for (final r in routes) {
      buffer.writeln('    GoRoute(');
      buffer.writeln("      path: '${r.routePath}',");
      buffer.writeln('      builder: (context, state) {');
      buffer.writeln('        return const ${r.componentClassName}();');
      buffer.writeln('      },');
      buffer.writeln('    ),');
    }

    buffer.writeln('  ],');
    buffer.writeln(');');

    return buffer.toString();
  }

  /// Default `test/widget_test.dart`
  static String widgetTest({required String projectName}) {
    return '''// test/widget_test.dart
import 'package:bloom_framework/bloom_testing.dart';
import 'package:$projectName/routes/index.dart';

void main() {
  testWidgets('Index route mounts and shows welcome message', (WidgetTester tester) async {
    await tester.pumpBloomApp(
      home: const IndexRoute(),
    );

    expect(find.text('Welcome to Bloom'), findsOneWidget);
  });
}
''';
  }

  /// `bloom.yaml` for a Flutter-free Bloom JS Native project.
  static String jsNativeBloomYaml({
    required String name,
    String version = '0.1.0',
    String description = 'A modern application built with Bloom JS Native',
  }) {
    return '''# Bloom Application Manifest
schema: 1

name: $name
version: $version
description: "$description"
type: js_native
# Marks this as a pure Dart web project (no Flutter) — `bloom add npm:<pkg>`
# and other CLI subsystems check this field to route to NPM/web handling
# instead of native mobile plugin handling.
target: web_dom

web:
  title: "$name"
  entry: lib/main.dart
  out: web/main.js

features:
  routing: false
  state: true
  data: false
  native: false
''';
  }

  /// `pubspec.yaml` for a Flutter-free Bloom JS Native project. No `flutter:`
  /// SDK dependency — `bloom js dev`/`bloom js build` compile with
  /// `dart compile js`, not the Flutter toolchain.
  static String jsNativePubspec({
    required String name,
    required String description,
    required String bloomJsNativeVersion,
  }) {
    return '''name: $name
description: "$description"
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  bloom_js_native: ^$bloomJsNativeVersion

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
''';
  }

  /// `web/index.html` for a Bloom JS Native project. Loads the compiled
  /// `main.js` produced by `bloom js dev` / `bloom js build`.
  static String jsNativeIndexHtml({required String name}) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
</head>
<body>
  <div id="app"></div>
  <!-- Compiled by `bloom js dev` / `bloom js build` from lib/main.dart -->
  <script src="main.js" defer></script>
</body>
</html>
''';
  }

  /// `lib/main.dart` for a Bloom JS Native project. Imports `browser.dart`
  /// (not the bare `bloom_js_native.dart` entry point) since `mount()` is
  /// browser-only — a common mistake that fails with
  /// "Error: Method not found: 'mount'." if omitted.
  static String jsNativeMainDart({required String projectName}) {
    return '''import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  final count = signal(0);

  final app = Div(
    className: 'app',
    children: [
      H1(text: 'Welcome to $projectName'),
      Live(() => P(text: 'Count: \${count.value}')),
      Button(
        text: 'Increment',
        onClick: (_) => count.value++,
      ),
    ],
  );

  mount(app, '#app');
}
''';
  }

  /// `test/smoke_test.dart` for a Bloom JS Native project — a plain `dart
  /// test` unit test against the SSR-safe core, not a browser test.
  static String jsNativeSmokeTest({required String projectName}) {
    return '''import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('count signal starts at 0 and increments', () {
    final count = signal(0);
    expect(count.value, 0);
    count.value++;
    expect(count.value, 1);
  });
}
''';
  }

  /// `AGENTS.md` for a Bloom JS Native project — a discoverable entry point
  /// for AI coding agents (and humans) so they read the cookbook and the
  /// two-entry-point rule before writing code, instead of guessing.
  static String jsNativeAgentsMd({required String projectName}) {
    return '''# $projectName — Bloom JS Native

This is a **Bloom JS Native** project: pure Dart, compiles to native
JavaScript, no Flutter. Read this file before writing or editing any code.

## Read first

Full docs live at `packages/bloom_js_native/COOKBOOK.md` in the Bloom
framework repo (or wherever your `bloom_js_native` package is vendored from —
check `.dart_tool/package_config.json` for its path). It is task-oriented
("How do I ...?") and has a section for every topic below.

## The one rule that trips everyone up

`bloom_js_native` has two entry points:

- `package:bloom_js_native/bloom_js_native.dart` — the core. Descriptors
  (`Div`, `Button`, `Live`, `Show`, `ForEach`), signals (`signal`, `computed`,
  `effect`), forms, routing, i18n. Pure Dart — safe on the server, in tests,
  in any shared/universal file.
- `package:bloom_js_native/browser.dart` — browser-only. `mount()`,
  `mountToElement()`, `hydrate()`, `BloomRouterController`, Web Component
  interop. Depends on `package:web` and real DOM APIs.

**`mount()` only exists in `browser.dart`.** If you import only
`bloom_js_native.dart` and call `mount()`, you get
`Error: Method not found: 'mount'.` Only `lib/main.dart` (the client entry
point) should import `browser.dart`; every other file — components, routes,
shared state — imports the base `bloom_js_native.dart`.

## Project layout

```
lib/
  main.dart          # entry point: builds the router, calls mount() — imports browser.dart
  app.dart            # top-level shell + BloomRouter route list
  routes/
    <page>.dart          # one BloomNode-returning function per route
  components/
    <component>.dart      # shared, reusable descriptors
  state/
    <domain>.dart           # shared Signal<T> instances
  design/
    tokens.dart               # designTokensCss const, injected via Style()
```

See COOKBOOK.md Section 3 ("Project Structure & Multi-File Apps") for the
full convention and examples. To add a page: create a file under
`lib/routes/`, add a `BloomRoute` entry for it in `lib/app.dart`, and reuse
anything already in `lib/components/` before writing a new descriptor.

## Commands

- `bloom js dev` — fast dev server with DDC live reload and hot remount, compiles `lib/main.dart`. Pass `--legacy-dart2js` to opt out to a whole-program `dart2js -O0` dev build instead.
- `bloom js build` — production bundle.
- `dart run bin/ssg.dart` — renders the static site to `dist/`. Run it only
  **after** `bloom js build`; the SSG must copy `web/main.js` to
  `dist/main.js`, plus vendor/assets and `lib/generated/fonts` to the served
  paths. A page that references `/main.js` without that output file has no
  hydration: links may navigate, but buttons, menus, dialogs, signals, and
  theme controls are inert. Verify `curl -I <preview>/main.js` returns 200.
- `bloom lint` — flags framework-specific bugs `dart analyze` can't see,
  including `untracked_signal_read`: a `.value` read directly inside
  UI-building code, outside `Live`/`Show`/`ForEach`/`effect`/`computed` (see
  the Reactivity checklist below). Run it before committing.
- `bloom generate controller <Name>` — scaffolds a `BloomController` under
  `lib/features/<feature>/controllers/` and a companion test under
  `test/features/<feature>/`.
- `dart test` — runs `test/`, which exercises SSR-safe code only (no
  `browser.dart` import in test files — the Dart VM has no DOM).
- `bloom fonts optimize --face "Family:weights:styles" --require-all-faces` —
  downloads self-hosted font manifests with exact per-family weights and styles
  (e.g. `bloom fonts optimize --face "Plus Jakarta Sans:300,400,500,600,700,800:normal" --face "JetBrains Mono:400,700:normal,italic" --require-all-faces`).
  Shared `--family`/`--weight`/`--style` applies the same faces to all families;
  strict mode (`--require-all-faces`) rejects unavailable faces instead of
  browser-synthesizing them.
- `bloom add npm:<package>` — install an npm package. Vendors a real ESM
  bundle into `web/vendor/`, generates a typed `@JS()` Dart binding at
  `lib/src/plugins/<package>.dart` from the package's real `.d.ts`, and
  wires both an importmap entry and a window-global bootstrap script into
  `web/index.html` automatically. Never hand-write vendor files or
  `<script>` tags for a JS dependency — always go through `bloom add`.
  `bloom remove <package>` undoes all of it.
- `bloom add npm:@tailwindcss/browser` — Tailwind CSS with no CDN `<script>`
  and no build step: `bloom add` gives it a dedicated self-executing script
  (it has no callable JS API, so no Dart binding is generated for it) that
  runs Tailwind's in-browser JIT engine, which scans the live DOM for
  utility classes. Just use `className: 'flex items-center gap-2'` etc.
  directly on any `BloomNode` afterward — see COOKBOOK.md Section 12 for
  the full recipe.

## Using an installed npm package from Dart

After `bloom add npm:<package>`, import the generated binding
(`lib/src/plugins/<package>.dart`) and call its top-level getter — do not
hand-write a new `@JS()` binding for a package you've already added.
The generated member list is a best-effort parse of the package's `.d.ts`;
if it falls back to a single guessed member (stated in a doc comment in the
generated file), verify that member name against the package's real docs
before calling it. A JS API whose entry point is itself a callable function
returning a chainable instance (not "an object with methods") isn't fully
modeled by the generator — extend the generated file by hand for that case,
the same way you'd write any other `@JS()` binding.

## Best practices checklist (read before writing code)

Full detail and rationale for every item below is in COOKBOOK.md Section 20
("Best Practices & Common Pitfalls Checklist") — this is the condensed
version so you don't have to open it for every edit.

### Reactivity
- Reading a signal outside `Live(...)` / `Show(...)` / `ForEach(...)`
  captures a one-time snapshot — it will never update on screen. Always wrap
  dynamic reads: `Live(() => P(text: 'Count: \${count.value}'))`, never
  `P(text: 'Count: \${count.value}')` directly in a non-reactive builder.
  `bloom lint`'s `untracked_signal_read` rule catches this.
- Update list/map signals by **reassigning** `.value`, never mutating the
  existing collection: `todos.value = [...todos.value, newItem];` — not
  `todos.value.add(newItem);`. The latter does not notify subscribers.
- Always pass `key:` to `ForEach` for any list that reorders, inserts, or
  removes items, e.g. `ForEach<Task>(() => tasks.value, (t) => Li(text:
  t.title), key: (t) => t.id)`. Without it, every update tears down and
  rebuilds all child DOM nodes.
- `Show(...)` with no `fallback` renders nothing when `when()` is false —
  pass `fallback:` explicitly if you need placeholder content.
- Reading a signal inside a plain Dart helper function (not a widget
  builder) still needs a reactive wrapper at the call site. Prefer
  `computed(() => ...)` for a derived value used in multiple places over
  wrapping the helper's call site in `Live(...)` — `Live()` is a DOM-node
  boundary, and reaching for it around a non-widget helper is usually a
  sign the computation belongs in a `computed()` instead.

### Modals, drawers, and overlays
- Mount dialogs/slide-overs (confirm modals, drawers, command palettes) at
  the **root of the app shell**, not nested inside `<main>` or any
  `overflow-y: auto` container. A `position: fixed` element inside a
  scrolling flex container does not create a true full-viewport overlay —
  sibling chrome (a fixed header/sidebar) stays lit and clickable in front
  of it.
- Track one `isOverlayActive` signal (or a stack if you can have more than
  one at a time) and apply a blur/`pointer-events: none` treatment to the
  rest of the shell while it's true, rather than relying on the overlay's
  own backdrop `<div>` to visually cover everything.

### Multi-character code inputs (OTP/PIN)
- Don't model a PIN/OTP entry as N separate `<input>` elements, one per
  digit. Each keystroke updates that box's signal, which re-renders the
  slot and drops browser focus without auto-advancing to the next box —
  typing and native backspacing both break.
- Use a single transparent/off-screen master `<input>` (one signal, one
  `maxLength`) positioned over N purely visual slot indicators that render
  from `Live(() => masterValue.value[i])`. This keeps continuous typing,
  paste, and backspace working natively, and pairs well with an optional
  on-screen keypad that just appends to the same signal.

### Events
- `BloomEvent.value` (`String?`) and `BloomEvent.checked` (`bool?`) are
  **nullable**. Never write `e.value!` — use `e.value ?? ''`. `value` is
  only populated for `<input>`/`<textarea>`/`<select>`; `checked` only for
  checkboxes/radios.
- `e.rawTarget` is untyped (`Object?`) and can be `null` in VM tests — don't
  assume it's non-null.

### The two entry points
- `package:bloom_js_native/bloom_js_native.dart` — pure Dart, safe
  everywhere (SSR, tests, shared files).
- `package:bloom_js_native/browser.dart` — `mount()`, hydration, router
  controller, Web Component interop. **Only `lib/main.dart` should import
  this.** Importing only the base package and calling `mount()` fails with
  `Error: Method not found: 'mount'.`

### SSR / hydration
- Reactive builders run exactly once, synchronously, under `renderToHtml()`
  — there's no server-side re-render loop.
- Event handlers, `Mount.onMount`/`onUnmount`, `Ref`, router listeners, and
  `effect()` all silently do nothing under SSR. Server-side logic (data
  fetching, redirects) belongs in loader/route-guard hooks, not these.
- For SSG/SSR output, call `hydrate(app, '#app')` in `lib/main.dart` — never
  `mount(app, '#app')`. `mount` appends a duplicate app beside the HTML;
  duplicate IDs cause double navbars, command palettes, and toast viewports.
  `hydrate` attaches in place or performs one clean remount for dynamic
  sentinels. Mount every global overlay exactly once at the app root.
- Reactive root trees currently remount on dynamic sentinels (`Live`, `Show`,
  `ForEach`). Avoid screenshot comparisons during initial font/CSS/animation
  startup, and mount browser-only state (global modals, toasts, theme listeners)
  cleanly at root.
- Responsive UI is CSS-first: use mobile-first media/container queries and
  responsive images (`bloomImage`, `bloomPicture`). Do not branch ordinary layout
  in Dart based on viewport; `HydrationStrategy.media` is for deferring
  interaction, not layout.
- Do not place required browser logic in a `Raw('<script>…</script>')` node
  emitted by SSR. A dynamic hydration remount recreates it and inserted
  scripts do not reliably run. Register browser listeners, focus work,
  observers, clipboard/theme bridges, and cleanup in `lib/main.dart` or
  `Mount.onMount`/`onUnmount` instead.
- Theme state has one signal as its source of truth. Toggle via a Dart event
  handler, update `html.dark`/`html.light` and `localStorage` in the
  browser-only bridge, and render icon/`aria-pressed` from that signal. Do
  not use a raw `onclick` string for state that must re-render.
- For blur/fade scroll reveals, preserve the initial hidden CSS state and
  add the visible class only as an element enters the viewport. Never add it
  to every target on startup: that removes the animation.

### Raw HTML and SVG
- `Raw` (`RawHtmlNode`) SSR/browser DOM has different behavior and should not
  be used as a general layout wrapper; prefer AST descriptors (`Div`, `Span`,
  `Svg`, etc.).
- Use SVG descriptors (`Svg`, `SvgPath`, etc.) for normal SVG, and test rendered
  browser output for complex raw SVG/media embeds.

### Disposal
Anything holding an external listener/observer/timer must be disposed on
teardown: `BloomMountHandle.unmount()`, `BloomRouterController.dispose()`,
`BloomVirtualizer.dispose()`, `BloomIslandOrchestrator.dispose()`,
`BloomController.onDispose()`, `BloomQuery.dispose()` /
`BloomInfiniteQuery.dispose()`.
- A `Timer`, periodic animation, or delayed focus started for a component
  belongs in `Mount.onMount` and must be cancelled in `Mount.onUnmount`.
  Never start it while building a node: `renderToHtml()` evaluates builders
  too, which can keep an SSG process alive or create client-only side effects.

### Command palettes and live inputs
- Keep the editable `<input>` outside the `Live` region that renders filtered
  results. Rebuilding an input on every keystroke destroys browser focus.
- Use `RefNode` plus `Mount.onMount` for focus after a modal actually enters
  the DOM. The `autofocus` attribute alone is unreliable after reactive
  insertion. Close on Escape/backdrop and test Cmd/Ctrl+K in a real browser.

### Styling and design tokens
- Define your design tokens (colors, radii, fonts) as a `const String` of
  raw CSS in `lib/design/tokens.dart`, injected once via `Style(tokensCss)`
  as the first child of your app shell — not pasted into `web/index.html`.
  `Style`/`Fragment` are real `BloomNode`s from the base package (no
  `browser.dart` import needed) and render correctly under both `mount()`
  and `renderToHtml()`.
- If using the UI primitives library (COOKBOOK.md Section 19), match its
  variable names (`--primary`, `--card`, `--radius-md`, etc. — full set in
  `lib/src/ui/tokens.dart`'s `uiTokensCss`) so its components pick up your
  theme instead of falling back to their own defaults.
- Load fonts with `bloom fonts optimize --face "Family:weights:styles" --require-all-faces`
  (e.g. `bloom fonts optimize --face "Plus Jakarta Sans:300,400,500,600,700,800:normal" --face "JetBrains Mono:400,700:normal,italic" --require-all-faces`).
  Shared `--family`/`--weight`/`--style` applies the same faces to every
  family; strict mode rejects unavailable faces rather than browser-synthesizing
  them. Inject generated `lib/generated/fonts/fonts.g.css` via
  `fontStylesheetLink()`.
- Visual parity: match exact source fonts, weights, and styles. Maintain one
  font stylesheet source in `<head>`, avoid duplicate font loads across
  CDN/@import/body, prefer static Tailwind output for screenshot comparisons
  rather than browser JIT, and compare browser-computed font metrics and line
  wrapping.
- Prefer `scopedCss()` for component-local styles — deterministic class
  names that match between SSR and hydration.
- Merge conditional class names with `cn([...])`, not string-interpolated
  ternaries.
- Keep `web/index.html` as close to empty as possible: `<meta>` tags,
  SEO/JSON-LD/`robots` content once you add those, and the `main.js` script
  tag. No design tokens, no font `<link>`s, no inline `<style>`/`<script>`
  logic, no hand-written DOM manipulation — all of that is Dart-driven and
  belongs in `lib/`.

### Testing
- `test/*.dart` files run on the Dart VM (no DOM) — never import
  `browser.dart` there. Test signals, computed values, `renderToHtml()`
  output, and route matching directly; `mount()`/hydration/real DOM events
  aren't unit-testable.

## Anti-fabrication note for AI agents

Do not guess component parameter names or signatures. Every UI primitive
(`button`, `dialog`, `select`, etc.) is documented with real, verified
signatures in COOKBOOK.md Section 19 ("UI Component Primitives") — read the
relevant recipe there before using one you haven't used before in this repo.
''';
  }

  /// `.gitignore` for a Bloom JS Native project.
  static String jsNativeGitignore() {
    return '''.dart_tool/
.packages
pubspec.lock
web/main.js
web/main.js.map
web/main.js.deps
web/vendor/
web/importmap.json
''';
  }
}
