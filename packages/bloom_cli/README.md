# Bloom CLI

[![pub package](https://img.shields.io/pub/v/bloom_cli.svg)](https://pub.dev/packages/bloom_cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

The official command-line interface for the **Bloom** application framework.

---

## 📦 Installation

Activate `bloom_cli` globally using Dart:

```bash
dart pub global activate bloom_cli
```

Make sure your pub cache `bin` directory is added to your system `PATH`.

To upgrade later, run `bloom upgrade`. Inside a project it also upgrades the
project's Bloom packages and fixes known breaking changes; `--dry-run`
previews, `--skip-cli` leaves the CLI alone. A one-line notice appears when a
new release is out (`BLOOM_NO_UPDATE_CHECK=1` turns it off; it never runs in
CI).

---

## 🛠️ Commands Overview

```bash
# Create a new project
bloom create my_app

# Create using a starter template
bloom create my_store --template ecommerce

# Start local interactive dev orchestrator
bloom dev

# Health and environment diagnostics
bloom doctor
bloom doctor --ci

# Native module authoring and sandbox
bloom create module my_sensor
bloom module dev
bloom module test

# Manage dependencies & native autolinking
bloom add bloom_camera
bloom deps
bloom why bloom_camera

# Asset optimization pipeline
bloom assets optimize
bloom assets analyze
bloom assets generate

# Security & dependency vulnerability audit
bloom audit
bloom security scan

# Architectural explanation & graph visualization
bloom explain route /users/42
bloom graph

# Package registry search
bloom registry search

# Upgrade the CLI and this project's Bloom packages, fixing breaking changes
bloom upgrade
bloom upgrade --dry-run   # preview; same report as `bloom doctor --upgrade`
```

---

## `bloom.yaml` editor support

New Flutter and JS Native projects include a YAML language server schema
comment. Editors that support this modeline provide completion and type
diagnostics for known manifest fields. The [schema](schema/bloom.schema.json)
also documents web, NPM, and proxy settings. Custom plugin fields remain open
for extension.

For an existing project, add this as the first line of `bloom.yaml`:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Chidi09/Bloom/main/packages/bloom_cli/schema/bloom.schema.json
```

---

## 📚 Documentation

For complete command references and architectural guides, see the [Bloom Documentation](https://github.com/bloom-framework/bloom).
