# Working on Bloom JS Native itself

Read this when the change is to the framework (the Bloom monorepo), not to an app built with it.

## Where things live

| Path | What it is |
|---|---|
| `packages/bloom_js_native/lib/bloom_js_native.dart` | Core entry point: pure Dart, VM-safe |
| `packages/bloom_js_native/lib/browser.dart` | Browser entry point: `mount`, `hydrate`, router controller, islands, web components |
| `packages/bloom_js_native/lib/src/` | Implementation (`framework.dart` descriptors, `mount.dart` DOM backend and hydration, `html.dart` SSR, `signals.dart`, `router*.dart`, `data.dart` queries…) |
| `packages/bloom_js_native/COOKBOOK.md` | Task-oriented docs, shipped in the pub package |
| `packages/bloom_js_native/reference/llms*.txt` | Generated API digest, shipped in the pub package |
| `packages/bloom_cli/lib/src/dev/` | `bloom js dev`: DDC compiler, signal-key injector (hot-reload state), live-reload server |
| `packages/bloom_cli/lib/src/templates/templates.dart` | Scaffold templates, including `jsNativeAgentsMd` (the `AGENTS.md` every new app gets) |
| `packages/bloom_cli/lib/src/lint/bloom_lint.dart` | `bloom lint` rules |
| `docs/js-native/` | Numbered guides 01–09 plus `KNOWN_ISSUES.md` |

## Keep the agent-facing docs in sync

Apps and agents learn the framework from three generated or hand-written surfaces. Keeping them correct is part of the change, not a follow-up:

1. **API reference.** After any public API change (new, renamed, or removed symbol, or a changed signature), regenerate it:
   ```bash
   cd packages/bloom_js_native && dart run tool/generate_reference.dart
   ```
   This rewrites `reference/llms-full.txt` and `reference/llms.txt` from `lib/`. Agents treat "not in llms.txt" as "doesn't exist", so a stale digest makes them avoid real APIs or miss new ones. Check with `git status reference/` that the output changed only where you expected.
2. **COOKBOOK.md.** If you change how a task is done, update its recipe. Section 20 (Best Practices & Pitfalls) is the long form of the scaffolded checklist.
3. **Scaffolded `AGENTS.md`** (`BloomTemplates.jsNativeAgentsMd` in `bloom_cli`). New projects carry this file forever, so update it when a convention, command, or pitfall changes. Existing projects keep their old copy, which is another reason the cookbook must stay authoritative.

Also update `docs/js-native/KNOWN_ISSUES.md` when you fix or discover a limitation, and add an entry under `## Unreleased` in the package's `CHANGELOG.md` (Added / Fixed / Security, one bullet per user-visible change).

## Test matrix

From `packages/bloom_js_native`:

```bash
dart analyze
dart test -p vm                                  # descriptors, SSR, data, router, signals
dart test -p chrome test/<file>_test.dart         # browser DOM tests (@TestOn('browser'))
bash tool/check.sh                               # everything, plus size budgets
```

- Browser tests need Chrome or Chromium. If it isn't on the default path, set `CHROME_EXECUTABLE`. Playwright's bundled Chromium works (`~/Library/Caches/ms-playwright/chromium-*/…/Google Chrome for Testing`). Run `tool/check.sh` with `bash`, because it relies on bash word-splitting.
- `tool/check.sh` enforces two gzip budgets: the example production build must stay ≤ 50 KiB, and the localized entry (`tool/i18n_size.dart`) ≤ 100 KiB. A new always-on import can quietly blow these.

For `packages/bloom_cli`:

```bash
dart test -j 1 --exclude-tags browser_e2e        # fast suite
PUPPETEER_EXECUTABLE_PATH=<chrome> dart test -j 1 --tags browser_e2e   # real DDC + browser hot-reload tests
```

CI (`.circleci/config.yml`) runs on Linux with the stable Dart SDK and **without Flutter**. Code that shells out to `flutter`, `java`, and so on must handle a missing executable (catch `ProcessException`), and tests that need Flutter must skip when it's absent. Timing-sensitive tests (file watchers, worker processes) behave differently on Linux than on macOS. If CI fails on something that passes locally, reproduce it in `docker run dart:stable`.

## Releasing

- The monorepo mixes public framework code with private cloud code. **Never push the repo's own remote directly.** `scripts/push-split.sh` filters the history to the public paths and pushes to `Chidi09/Bloom` (and optionally the private split). Use `DRY_RUN=1` first and `SKIP_PRIVATE=1` for public-only pushes. The script refuses to push if private paths survive the filter.
- Before publishing, run `dart pub publish --dry-run` in each package. Publish in dependency order: `bloom_js_native` before packages that depend on its new APIs (`bloom_server`, `bloom_seo`). Raise dependents' constraints (e.g. `bloom_js_native: ^0.3.8`) when they start using a new API. Local `dependency_overrides` hide a stale constraint, and pub ignores them on publish.
