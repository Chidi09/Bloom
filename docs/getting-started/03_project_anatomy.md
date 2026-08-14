# 3. Project Anatomy & Directory Structure

When you execute `bloom create <project_name>`, Bloom generates a clean, domain-driven Flutter project structure designed for enterprise scale and zero architectural drift.

---

## 🗂️ Complete Directory Hierarchy

```text
my_bloom_app/
├── bloom.yaml                  # Centralized application manifest (config, plugins, native, deployment)
├── .env                        # Default environment variables
├── .env.local                  # Local overrides (git-ignored)
├── pubspec.yaml                # Standard Flutter package dependencies
├── android/                    # Android native host project (managed by prebuild)
├── ios/                        # iOS native host project (managed by prebuild)
├── web/                        # Web platform scaffolding & deep link domain files
└── lib/
    ├── main.dart               # Framework bootstrapper entrypoint
    ├── app/
    │   ├── app.dart            # Root BloomApp widget configuration & theme
    │   ├── boot.dart           # Dependency Injection & startup bootstrapper
    │   └── routes.g.dart       # AUTO-GENERATED: GoRouter filesystem routing table
    ├── routes/                 # Filesystem-based page and modal declarations
    │   ├── index.dart          # Root home screen ('/')
    │   ├── counter.dart        # Route at '/counter'
    │   ├── profile.dart        # Route at '/profile'
    │   └── settings.dart       # Route at '/settings'
    ├── features/               # Domain feature modules (controllers, state, UI widgets)
    │   ├── auth/
    │   └── counter/
    │       └── counter_controller.dart
    ├── models/                 # Strongly-typed data models and JSON serialization
    ├── services/               # Backend API services, repositories, and network clients
    └── config/                 # Custom domain configuration constants and themes
```

---

## 🔍 Detailed Breakdown of Key Files

### 1. `bloom.yaml`
The single source of truth for the entire application. Configures application name, platform SDK versions, enabled framework features, build flavors, native plugins, deep linking domains, and Shorebird OTA code-push updates.

### 2. `lib/main.dart`
The Flutter entry point. Boots the framework with a single line:
```dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/app.dart';
import 'app/boot.dart';

void main() async {
  await Bloom.boot(bootstrapper: AppBootstrapper());
  runApp(const MyApp());
}
```

### 3. `lib/app/boot.dart`
Implements `BloomBootstrapper`. Used to register dependencies, database clients, authentication sessions, and services inside Bloom's DI container (`BloomContainer`) before the first frame mounts.

### 4. `lib/app/routes.g.dart` (Auto-Generated)
The Bloom CLI scans `lib/routes/` and compiles filesystem conventions into a strongly-typed `GoRouter` instance. **Never edit this file manually**; it is automatically refreshed during `bloom dev`, `bloom prebuild`, and `bloom deploy`.

### 5. `lib/routes/`
Declares your application's navigation graph via filesystem conventions:
* `index.dart` ➔ Route `/`
* `users.dart` ➔ Route `/users`
* `users/[id].dart` ➔ Route `/users/:id` (captures dynamic path parameter `id`)
* `(auth)/login.dart` ➔ Route `/login` (route groups allow organization without altering URL structure)
* `_layout.dart` ➔ Shell layout wrapping child routes in persistent bottom navigation or sidebars.

### 6. `.env` and `.env.local`
Key-value configuration loaded at boot time by `BloomEnv`. `.env.local` overrides values from `.env` for local machine customization and is automatically added to `.gitignore`.
