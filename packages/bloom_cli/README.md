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

# Automated framework upgrades & AST migrations
bloom upgrade
bloom doctor --upgrade
```

---

## 📚 Documentation

For complete command references and architectural guides, see the [Bloom Documentation](https://github.com/bloom-framework/bloom).
