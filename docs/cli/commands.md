# Additional CLI Commands (`add`, `remove`, `build`, `test`, `analyze`)

Reference manual for secondary Bloom workflow commands.

---

## ➕ `bloom add`

Activates a native plugin or feature in `bloom.yaml` and executes prebuild synchronization.

### Synopsis
```bash
bloom add <plugin_name>
```

### Plugin Name Resolution & Validation
`bloom add` validates `<plugin_name>` against `BloomPluginCatalog`:
* Input names are canonicalized: trimmed, lowercased, and hyphens (`-`) converted to underscores (`_`). For example, `secure-storage`, `secure_storage`, and `Secure-Storage` all resolve to the canonical ID `secure_storage`.
* The canonical ID is written into `bloom.yaml`.
* If an unrecognized plugin name is provided, `bloom add` prints an error with supported plugin IDs and exits with code `1` without modifying `bloom.yaml` or running prebuild.

### Supported Plugins
* `auth`
* `background_tasks` (or `background-tasks`)
* `camera`
* `deep_links` (or `deep-links`)
* `location`
* `notifications`
* `secure_storage` (or `secure-storage`)
* `storage`

---

## ➖ `bloom remove`

Deactivates a native plugin or feature in `bloom.yaml` and synchronizes platform manifests.

### Synopsis
```bash
bloom remove <plugin_name>
```

### Plugin Name Resolution & Validation
* Validates and canonicalizes `<plugin_name>` against `BloomPluginCatalog` (matching both canonical and hyphenated forms).
* Removes the plugin entry from `bloom.yaml` and executes prebuild synchronization.
* If an unrecognized plugin name is provided, prints an error with supported plugin IDs and exits with code `1`.

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
