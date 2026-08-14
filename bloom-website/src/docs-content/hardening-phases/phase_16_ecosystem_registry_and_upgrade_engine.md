# Phase 16: Ecosystem Registry, Upgrade Engine & Continuous Doctor

> **Objective:** Deliver the framework upgrade migration engine (`bloom upgrade`), breaking-change analyzers, the Bloom Package Registry, compatibility badges, architectural graph visualizations (`bloom graph`), and continuous CI diagnostics.

---

## 🏗️ Ecosystem Governance Architecture

```text
            Bloom Framework Evolution
                        │
      ┌─────────────────┴─────────────────┐
      ▼                                   ▼
bloom upgrade                      bloom registry
(Automated AST Migrations)        (Verified Modules)
      │                                   │
      ▼                                   ▼
Breaking Change Analyzer          Compatibility Badges
(Scans routes, signals, config)  (Bloom 1.x, Flutter 3.x)
      │                                   │
      └─────────────────┬─────────────────┘
                        ▼
            Continuous CI Health Agent
```

---

## 🔄 1. Automated Framework Upgrades (`bloom upgrade`)

`bloom upgrade` upgrades Bloom packages, CLI tools, and executes AST code migrations across major breaking releases:

```bash
# Preview planned migrations without touching files
bloom upgrade --dry-run

# Execute full upgrade and AST transformations
bloom upgrade
```

### Automated Migration Steps
1. **Dependency Constraints:** Updates `bloom_framework` and ecosystem module versions in `pubspec.yaml`.
2. **Configuration Migrations:** Upgrades `bloom.yaml` to the latest schema version.
3. **AST Code Migrations:** Refactors deprecated API calls, route declarations, or controller signatures automatically using Dart analysis server AST rewrites.

---

## ⚠️ 2. Breaking-Change Analyzer (`bloom doctor --upgrade`)

Before applying an upgrade, the analyzer inspects your codebase for potential incompatibilities:

```bash
bloom doctor --upgrade
```

**Output:**
```text
🔍 Bloom Upgrade Compatibility Analysis (v1.0 ➔ v2.0)

✔ State Management:   100% compatible (No deprecated Signals APIs found)
✔ Data Layer:          100% compatible (BloomData queries & mutations aligned)
⚠ Routing:             2 legacy Route Guards require refactoring:
  • lib/routes/admin.dart:12 ➔ CustomGuard must implement BloomGuard interface
✓ Native Modules:      All installed modules compatible with Flutter 3.27+
```

---

## 🏛️ 3. Bloom Package Registry & Compatibility Badges

A curated directory of community and official Bloom modules, plugins, and UI design systems:

### Tiered Verification Badges
* 🏆 **Official:** Maintained directly by the Bloom core framework team.
* 🛡️ **Verified:** Passed automated compatibility tests against the Bloom CI matrix.
* 🌐 **Community:** Open-source community contributions.

```yaml
# In bloom.module.yaml:
bloom:
  type: module
  verification: verified
  compatibility:
    bloom: ">=1.0.0 <2.0.0"
    flutter: ">=3.24.0"
    platforms:
      android: ">=24"
      ios: ">=15.0"
```

---

## 💡 4. Architectural Explanation Tools

### `bloom explain <topic>`
Explains framework decisions, routing rules, or dependency choices:

```bash
bloom explain route /users/42
```
**Output:**
```text
Route: /users/42
  • File: lib/routes/users/[id].dart
  • Pattern: /users/:id
  • Parameters: {id: '42'}
  • Layout: lib/routes/_layout.dart (ShellRoute)
  • Guards: [BloomAuthGuard (redirect: /login)]
```

### `bloom graph`
Generates an interactive visual dependency graph of your application:
```bash
bloom graph
```
Renders the complete relationship graph: `Routes ➔ Controllers ➔ Queries ➔ Repositories ➔ HTTP Services`.

---

## 🤖 5. Continuous CI Doctor Agent

Integrate `bloom doctor --ci` into GitHub Actions, GitLab CI, or Codemagic:

```yaml
# .github/workflows/bloom_ci.yml
name: Bloom Continuous Verification

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
      - name: Install Bloom CLI
        run: dart pub global activate bloom_cli
      - name: Run Continuous Doctor Check
        run: bloom doctor --ci
      - name: Run Monorepo Test Matrix
        run: bloom test
```

---

## 🧪 Verification & Acceptance Criteria

> See [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md). Anti-patterns A1–A6 apply.

### C1. `bloom upgrade --dry-run` computes real diffs
- **When** run against a project behind a major version.
- **Then** lists planned dependency/config/AST migrations without altering files.
- **Must not** print a plan without diffing against the target version (A1).
- **Test** fixture → assert dry-run lists migrations and leaves files byte-identical.

### C2. `bloom upgrade` actually migrates
- **When** run without `--dry-run`.
- **Then** `pubspec.yaml`, `bloom.yaml`, and deprecated API calls are rewritten to the new schema.
- **Must not** report success while files are unchanged (A1).
- **Test** fixture → assert files changed to expected post-migration content.

### C3. `bloom doctor --upgrade` detects real breaking changes
- **When** the codebase uses a deprecated API.
- **Then** flags `file:line` and suggests the replacement.
- **Must not** report "100% compatible" when deprecated APIs exist (A1).
- **Test** fixture with a deprecated call → assert detection + line number.

### C4. `bloom doctor --ci` returns non-zero on real problems
- **When** a build conflict, security risk, or duplicate native module exists.
- **Then** exits non-zero with a structured report.
- **Must not** always exit 0 (A1).
- **Test** fixture with a seeded problem → assert non-zero exit.

### C5. `bloom explain` reports accurate, derived info
- **When** `bloom explain route /users/42`.
- **Then** reports the file/pattern/params **derived** from the route tree, not canned text.
- **Must not** return hardcoded text for unknown routes (A2).
- **Test** fixture route → assert output matches the real file/pattern/params.

### C6. Registry badges are derived from verification, not self-declared
- **When** a module passes the CI compatibility matrix.
- **Then** it is marked `Verified` automatically.
- **Must not** allow a module to self-declare `Verified` without passing the matrix (A2/A3).
- **Test** registry test asserting badge reflects actual test results.
