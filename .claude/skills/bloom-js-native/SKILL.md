---
name: bloom-js-native
description: "Build, debug, and extend web apps with Bloom JS Native (the `bloom_js_native` Dart package): reactive Dart components rendered to real DOM with signals, SSR/SSG/hydration, routing, forms, queries, islands, and the `bloom` CLI. Use this skill whenever the user is working in a Bloom JS Native project or on the framework itself: they mention Bloom, bloom_js_native, `bloom create --js-native`, `bloom js dev`/`build`/`create`, `bloom lint`, or Dart web code using `Live`, `Show`, `ForEach`, `signal()`, `mount()`, `hydrate()`, `BloomRoute`, or `renderToHtml()`. Also use it when a project has an AGENTS.md that mentions Bloom, even if the user doesn't name the framework. Bloom JS Native is new, so model memory of its API is unreliable. This skill tells you where the verified docs are and how to use them before writing code."
---

# Bloom JS Native

Bloom JS Native is a Dart web framework: components build a pure-Dart descriptor tree (`BloomNode`), which either mounts to real DOM with fine-grained signal effects or renders to an HTML string for SSR/SSG. It is **not** Flutter on the web, and there's no virtual DOM.

It's a young framework. There are no blog posts or Stack Overflow answers for it, and your training data knows little or nothing about it. Plausible-looking guesses (React idioms, Flutter widget names, invented parameters) are the main source of bugs. So the job is less "remember the API" and more "find the verified API quickly and follow it".

## Step 1: Orient: find the project's docs

Bloom ships its own agent documentation. Read it before writing code.

1. **The project's `AGENTS.md`.** `bloom create <name> --js-native` scaffolds an `AGENTS.md` at the project root, written for coding agents. It covers the two-entry-point rule, the project layout convention (`lib/routes/`, `lib/components/`, `lib/state/`, `lib/design/tokens.dart`), every CLI command, and a condensed best-practices checklist. If it exists, read it first and follow it. It's the project's own contract and wins over anything generic here. If the project predates the scaffold or was made by hand, it won't exist; that's fine.
2. **`COOKBOOK.md` and `reference/`, shipped inside the package.** Run the bundled locator to find the copies that match the version the project actually resolves:
   ```bash
   bash <this-skill-dir>/scripts/locate_docs.sh [project_dir]
   ```
   It prints the paths to `AGENTS.md`, `COOKBOOK.md`, `reference/llms.txt`, and `reference/llms-full.txt`. (Run `dart pub get` first if it reports the package as unresolved.) Inside the Bloom repo itself these live at `packages/bloom_js_native/`.

## Step 2: Ground every API use in the reference

Use these in order, from cheapest to most detailed:

| Source | Use it for | How |
|---|---|---|
| `reference/llms.txt` (~900 lines) | "Does this symbol exist, and in which entry point?" | One line per public symbol, grouped by file and tagged `core` or `browser-only`. **If a symbol isn't listed, it doesn't exist.** Don't invent it. |
| `reference/llms-full.txt` (~10k lines) | Exact signature, parameters, and doc comment | Too big to read whole. `grep -n -A30 'class BloomRoute\b'` or similar around the symbol you need. |
| `COOKBOOK.md` (~4k lines) | "How do I…?" recipes with working code | Jump to the relevant section (map below) with `grep -n '^## '`. |
| Package source (`lib/src/*.dart`) | Behavior the docs don't settle | Last resort; also the tiebreaker if docs and source disagree. |

For UI component primitives (buttons, dialogs, selects, and so on), always read their recipe in COOKBOOK section 19 before using one. Their parameter names are specific, and guessing them fails in a way that looks right.

### Cookbook section map

| # | Section | Reach for it when… |
|---|---|---|
| 3 | Project Structure & Multi-File Apps | adding pages, components, or shared state files |
| 4 | Getting Something on Screen | entry points, `mount`, first render |
| 5 | State and Reactivity | `signal`/`computed`/`effect`/`batch`, controllers, reducers, context |
| 6 | Lists and Conditionals | `ForEach` keys, `Show`, `Memo` |
| 7 | Forms | `BloomForm`, fields, validators, file inputs |
| 8 | Data Fetching and Mutations | `query`, `infiniteQuery`, `mutation`, invalidation |
| 9 | Routing | `BloomRouter`, `BloomRoute`, guards, loaders, `Link` |
| 10 | SSR & Hydration | `renderToHtml`, streaming Suspense, `hydrate`, islands |
| 11 | Styling | `Style`, `scopedCss`, tokens, Tailwind |
| 12 | Interop and Web Components | npm via `bloom add npm:`, `@JS()`, custom elements |
| 13 | i18n and Images | `BloomI18n`, formatting, `bloomImage`/`bloomPicture` |
| 14 | Accessibility | `aria()`, live regions, focus |
| 15 | Performance and Scheduling | transitions, virtualization, lazy loading |
| 16 | Testing | `renderForTest`, `fireEvent`, VM vs browser tests |
| 17 | Error Handling | `ErrorBoundary`, dev overlay |
| 18 | Backend-for-Frontend | pairing with `bloom_server`, RPC contracts |
| 19 | UI Component Primitives | any prebuilt UI component: read before use |
| 20 | Best Practices & Pitfalls | before finishing any non-trivial change |

## Step 3: Write code that respects the framework's model

`AGENTS.md` and COOKBOOK section 20 have the full checklist. These are the rules that cause most breakage, with the reason behind each so you can handle cases the list doesn't cover:

- **Two entry points.** `package:bloom_js_native/bloom_js_native.dart` is pure Dart: descriptors, signals, router, forms, SSR. It's safe on the server and in VM tests. `package:bloom_js_native/browser.dart` adds `mount`, `hydrate`, `BloomRouterController`, islands, and web components, and depends on real DOM. Only the client entry (`lib/main.dart`) should import `browser.dart`. Anything shared must stay importable on the VM, or SSR and tests break. The symptom is `Method not found: 'mount'`, or a VM test that fails to compile.
- **Reactivity is scoped by wrappers, not by components.** A `signal.value` read only updates the screen if it happens inside `Live`, `Show`, `ForEach`, `Memo`, `computed`, or `effect`. A bare read in a builder captures a one-time snapshot. `bloom lint` (rule `untracked_signal_read`) catches this. For a derived value used in several places, prefer `computed()` over scattering `Live` wrappers.
- **Signals notify on assignment, not mutation.** Use `todos.value = [...todos.value, item]`, never `todos.value.add(item)`.
- **Key every dynamic list.** `ForEach(..., key: (t) => t.id)`. Without a key, every update rebuilds all rows, which drops focus and input state. Hydration and hot reload also match rows by key.
- **Keep inputs outside the `Live` region they drive.** Rebuilding an `<input>` on each keystroke destroys focus.
- **SSR runs builders once and runs no browser code.** Event handlers, `Mount.onMount`/`onUnmount`, `Ref`, router listeners, and `effect()` don't run under `renderToHtml()`. Server data belongs in route loaders or guards. Timers, observers, and focus work go in `Mount.onMount` and are cleaned up in `onUnmount`, never started while building nodes, because builders also run during SSG and that can hang the process.
- **Server-rendered pages hydrate; they don't mount.** Call `hydrate(app, '#app')` for SSR/SSG output. `mount` appends a second copy of the app. Don't rely on `Raw('<script>…')` for required behavior: a hydration fallback can recreate DOM and inserted scripts don't reliably run.
- **Dispose what holds external resources.** Mount handles, router controllers, virtualizers, island orchestrators, controllers, and queries all have `dispose`/`unmount`.
- **Use the CLI for npm packages.** `bloom add npm:<pkg>` vendors the ESM bundle, generates a typed binding under `lib/src/plugins/`, and wires the import map. Never hand-write vendor files or `<script>` tags.

### Hot reload (`bloom js dev`)

The DDC dev server preserves state across edits for top-level signals and for signals created inside the supported callbacks (`Live`, `Show`, `Memo`, `Suspense`, `ErrorBoundary`, `Mount`, `effect`, `lazy`, event handlers, keyed `ForEach`). Constructor calls assigned to variables at stable call sites get per-instance scopes too. Anything else loses state on reload, including signals in *unkeyed* repeated builders, top-level factory functions, and inline imported constructors. Give those an explicit `key:` on `signal()`. When a user reports "state resets on save", this is the first thing to check. The current list is in the repo's `docs/js-native/KNOWN_ISSUES.md`.

## Step 4: Verify before calling it done

Run the checks that apply, and report real results. A change that compiles but reads a signal outside a reactive wrapper looks fine in review and is broken on screen.

```bash
dart analyze
bloom lint                 # framework-specific bugs dart analyze can't see
dart test                  # VM tests: descriptors, renderToHtml output, routing, signals
bloom js dev               # then exercise the change in a real browser
bloom js build             # production bundle
```

- VM tests can't import `browser.dart` and can't test `mount()`, hydration, or real DOM events. Use `renderForTest()` + `fireEvent` for component logic. Behavior that depends on the DOM needs a real browser (`dart test -p chrome` on a `@TestOn('browser')` file, or manual checks in `bloom js dev`).
- For SSG sites, run `bloom js build` before `dart run bin/ssg.dart`, and confirm `/main.js` is actually served (`curl -I <url>/main.js` returns 200). Without it the page renders but nothing is interactive.

## Working on the framework itself

If the task is changing Bloom (the `packages/bloom_js_native` package, the `bloom_cli` dev server and scaffolds, or the docs), read `references/contributing.md` in this skill. It covers the test matrix (VM, Chrome, and the size budgets), regenerating the API reference, keeping the scaffolded `AGENTS.md` template and the cookbook in sync with code changes, changelog conventions, and how the repo is pushed and released.
