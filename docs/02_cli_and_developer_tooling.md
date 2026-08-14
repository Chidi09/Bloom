# 02. Bloom CLI & Developer Tooling

## 1. Overview

The **Bloom CLI** (`bloom`) is the developer's primary interface to the framework. It orchestrates Flutter tooling, validates conventions, generates deterministic code, and manages application lifecycles.

```bash
dart pub global activate bloom_cli
```

---

## 2. CLI Command Matrix

| Command | Purpose | Underlying Mechanism |
| :--- | :--- | :--- |
| `bloom create <app> [--template <name>]` | Initializes a new standardized Bloom application from template | `flutter create` + Bloom architecture scaffolds |
| `bloom dev` | Starts interactive development server & device manager with wireless pairing | Orchestrates `flutter run` + LAN UDP discovery & TUI |
| `bloom generate <type> <name>` | Scaffolds deterministic routes, pages, controllers, models | Bloom AST generator / templates |
| `bloom doctor [--ci] [--upgrade]` | Validates environment, CI health, secrets, autolink, breaking changes | System checks + security scanner + AST deprecation analyzer |
| `bloom add <plugin>` | Adds & autolinks official/community native Bloom plugins | Updates `bloom.yaml`, autolinks native Android/iOS AST |
| `bloom remove <plugin>` | Removes plugin and cleans native configurations | Updates `bloom.yaml` & prunes native configs |
| `bloom deps` / `bloom why <pkg>` | Inspects native autolink graph and reasons for inclusion | Native dependency tree analyzer |
| `bloom workspace [info\|sync]` | Resolves and validates monorepo workspace dependencies | Monorepo root AST parser |
| `bloom create module <name>` | Scaffolds a new native module package with DSL | Dart ↔ Swift/Kotlin binding generator |
| `bloom module dev` / `bloom module test`| Runs isolated sandbox dev server and multi-platform native tests | Sandbox test runner & harness |
| `bloom assets optimize\|analyze\|generate`| Compresses assets, audits disk footprint, generates typed icons | Asset compression & code generation engine |
| `bloom audit` / `bloom security scan` | Audits dependencies for known CVEs and scans for exposed secrets | Security vulnerability DB & regex entropy scanner |
| `bloom explain route <path>` | Explains route hierarchy, parameters, guards, and layout tree | Bloom route AST analyzer |
| `bloom graph` | Generates visual dependency graphs (ASCII / Mermaid) | Architectural graph generator |
| `bloom registry search\|info` | Queries Bloom ecosystem package registry with CI badges | Verified package index client |
| `bloom upgrade [--dry-run]` | Upgrades framework dependencies and runs automated AST code migrations | AST refactoring & migration engine |
| `bloom symbols package\|upload` | Packages debug symbols and dSYMs for observability crash reporting | Symbol map packager & multipart uploader |
| `bloom templates list` | Lists all official and community starter templates | Template registry client |
| `bloom analyze` | Performs strict linting and convention checking | `dart analyze` + Bloom custom rules |
| `bloom test` | Runs unit, widget, and integration test suites | `flutter test` with structured output |
| `bloom prebuild` | Generates Android/iOS native files from `bloom.yaml` | Bloom native configuration generator |
| `bloom build <target>` | Compiles production binaries (apk, ipa, web, desktop) | `flutter build` + environment injection |
| `bloom deploy` | Deploys OTA patches or uploads web/app artifacts | Shorebird integration / Cloud connectors |

---

## 3. `bloom create` Sequence

```text
bloom create <app_name>
        ↓
Validate Project Name (Dart package naming rules)
        ↓
Check System Primitives (Dart SDK & Flutter CLI)
        ↓
Invoke base `flutter create` (Platform scaffolds)
        ↓
Inject Bloom Runtime Dependency (`bloom_framework`)
        ↓
Create Bloom Directory Structure (routes/, features/, config/)
        ↓
Generate `bloom.yaml` Configuration Manifest
        ↓
Generate `.env` and `.env.example`
        ↓
Generate Initial Route (`lib/routes/index.dart`)
        ↓
Generate Boot Sequence (`lib/app/boot.dart`)
        ↓
Run Initial Code Analysis & Smoke Test
        ↓
Project Ready for Development
```

### Initial Project Structure

```text
my_app/
├── android/
├── ios/
├── web/
├── assets/
├── lib/
│   ├── app/
│   │   ├── app.dart             # Root BloomApp widget
│   │   ├── boot.dart            # Framework boot & service registration
│   │   └── providers.dart       # Core dependency bindings
│   ├── config/
│   │   └── app_config.dart      # Strongly typed config access
│   ├── routes/
│   │   ├── index.dart           # Home route ('/')
│   │   └── [generated_routes]   # Filesystem routes
│   ├── features/
│   │   └── auth/                # Feature-first domain modules
│   │       ├── controllers/
│   │       ├── models/
│   │       ├── services/
│   │       └── widgets/
│   └── main.dart                # Entry point invoking Bloom.boot()
├── test/
├── .env
├── .env.example
├── bloom.yaml                   # Central project manifest
└── pubspec.yaml
```

---

## 4. `bloom.yaml` Manifest Specification

```yaml
# Schema versioning allows independent schema evolution
schema: 1

name: my_app
version: 0.1.0
description: "A production Bloom application"

# Native target configuration
platforms:
  android:
    min_sdk: 24
    target_sdk: 34
    package: com.example.myapp
  ios:
    minimum_version: "15.0"
    bundle_identifier: com.example.myapp
  web:
    title: "My Bloom App"

# Framework feature flags
features:
  routing: true
  state: true
  data: false        # Enabled in Bloom v0.2
  native: false      # Enabled in Bloom v0.3

# Environment file resolution order (later overrides earlier)
environment:
  files:
    - .env
    - .env.local

# Declarative native plugin integrations
plugins:
  - secure_storage
  - notifications:
      enabled: true
      channels:
        - id: general
          name: General Alerts
```

---

## 5. Code Generation (`bloom generate`)

Bloom provides fast, deterministic CLI scaffolding commands without requiring long-running background watchers.

```bash
# Generate a new filesystem route and page
bloom generate page users
# -> Creates lib/routes/users/index.dart
# -> Updates generated router table

# Generate a parameterized route
bloom generate route "users/[id]"
# -> Creates lib/routes/users/[id].dart

# Generate a state controller
bloom generate controller AuthController
# -> Creates lib/features/auth/controllers/auth_controller.dart

# Generate a typed model
bloom generate model User
# -> Creates lib/models/user.dart

# Generate a service or repository
bloom generate service ApiService
# -> Creates lib/services/api_service.dart
```

### Code Generation Policies
1. **Marked Outputs:** Generated files are placed in dedicated `generated/` directories or explicitly stamped:
   ```dart
   // GENERATED BY BLOOM. DO NOT MODIFY DIRECTLY.
   ```
2. **Safe Code Updates:** Bloom never uses blind regex or string substitution on user files. It modifies files strictly via AST transformations, generated part files, or explicit developer insertion markers.
3. **Deterministic Scaffolding:** Running `bloom generate` produces the exact same output across machines and environments.
