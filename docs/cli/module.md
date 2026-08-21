# `bloom module` & `bloom autolink` CLI Reference Manual

The Bloom Native Module Platform allows developers to scaffold, develop, test, and autolink native Swift and Kotlin plugins using the `@BloomModule` DSL.

---

## 1. `bloom create module` — Scaffold Native Module

Scaffolds a new standalone native plugin package with typed Dart, Swift (iOS), and Kotlin (Android) interfaces.

```bash
bloom create module <module_name> [options]
```

### Generated Structure
```
bloom_biometrics/
├── lib/
│   └── bloom_biometrics.dart    # Dart public interface
├── android/
│   └── src/main/kotlin/...      # Kotlin Android implementation
├── ios/
│   └── Classes/...              # Swift iOS implementation
└── bloom.yaml                   # Module descriptor & autolink config
```

---

## 2. `bloom autolink` — Automatic Dependency Linking

Scans your project's `pubspec.yaml` and `bloom.yaml` for native Bloom modules and automatically wires their Gradle and CocoaPods build scripts into the host mobile applications.

```bash
bloom autolink
```

* Eliminates manual editing of `settings.gradle` or `Podfile`.
* Resolves transitive native dependency collisions automatically.

---

## 3. `bloom module dev` & `bloom module test`

* **`bloom module dev`**: Launches an isolated sandbox application to test and iterate on your native module in real time.
* **`bloom module test`**: Executes native unit tests on connected Android emulators and iOS simulators.
