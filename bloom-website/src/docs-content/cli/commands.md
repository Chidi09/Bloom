# Additional CLI Commands (`add`, `remove`, `build`, `test`, `analyze`)

Reference manual for secondary Bloom workflow commands.

---

## ➕ `bloom add`

Activates a native plugin or feature in `bloom.yaml` and executes prebuild synchronization.

### Synopsis
```bash
bloom add <plugin_name>
```

### Supported Plugins
* `bloom add secure-storage`
* `bloom add camera`
* `bloom add notifications`
* `bloom add background-tasks`
* `bloom add auth`

---

## ➖ `bloom remove`

Deactivates a native plugin in `bloom.yaml` and synchronizes platform manifests.

### Synopsis
```bash
bloom remove <plugin_name>
```

---

## 🏗️ `bloom build`

Builds target production platform artifacts (APK, App Bundle, iOS IPA, Web bundle).

### Synopsis
```bash
bloom build <target> [options]
```

### Supported Targets
* `apk` — Builds release Android APK (`flutter build apk`).
* `appbundle` — Builds Google Play Android App Bundle (`flutter build appbundle`).
* `ipa` — Builds iOS archive (`flutter build ipa`).
* `web` — Compiles Web production bundle with optimized canvas kit renderer (`flutter build web`).

### Options
* `--flavor <name>` — Target build flavor.
* `--release` — Compile release binary.

---

## 🧪 `bloom test`

Runs unit, widget, and integration tests across the Bloom project with test scope isolation.

### Synopsis
```bash
bloom test [path] [options]
```

### Options
* `--coverage` — Collect code coverage data into `coverage/lcov.info`.

---

## 🔍 `bloom analyze`

Performs static analysis across all Dart and Flutter code, ensuring zero compiler warnings or lint errors.

### Synopsis
```bash
bloom analyze [options]
```

### Exit Codes
* `0`: Clean analysis with 0 warnings or errors.
* `1`: Lint or compilation issues detected.
