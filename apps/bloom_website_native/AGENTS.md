# bloom_website_native — Bloom JS Native

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
  dynamic reads: `Live(() => P(text: 'Count: ${count.value}'))`, never
  `P(text: 'Count: ${count.value}')` directly in a non-reactive builder.
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
- Do not place required browser logic in a `Raw('<script>…</script>')` node
  emitted by SSR. A dynamic hydration remount recreates it and inserted
  scripts do not reliably execute. Register browser listeners, focus work,
  observers, clipboard/theme bridges, and cleanup in `lib/main.dart` or
  `Mount.onMount`/`onUnmount` instead.
- Theme state has one signal as its source of truth. Toggle via a Dart event
  handler, update `html.dark`/`html.light` and `localStorage` in the
  browser-only bridge, and render icon/`aria-pressed` from that signal. Do
  not use a raw `onclick` string for state that must re-render.
- For blur/fade scroll reveals, preserve the initial hidden CSS state and
  add the visible class only as an element enters the viewport. Never add it
  to every target on startup: that removes the animation.

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
- Load fonts with `bloom fonts optimize --family <name> --weight <n>`
  (self-hosts `.woff2`, generates `fonts.g.css` with a CLS-mitigation
  fallback face) and inject the result with `fontStylesheetLink()` from
  Dart, in the same `Fragment` as your `Style(tokensCss)` call — never a
  Google Fonts CDN `<link>` in `web/index.html`.
- When matching a reference design, verify the generated font files contain
  the Latin subset used by the page and compare browser-computed font family,
  weight, size, and line wrapping. A tiny non-Latin Unicode subset can load
  successfully yet silently fall back for English text and change all hero
  metrics.
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
