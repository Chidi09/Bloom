# `bloom prebuild`

Executes the Bloom Native Prebuild Engine. Synchronizes declarative platform configuration, native plugin entitlements, permissions, deep linking intent filters, and SDK constraints directly into Android and iOS host projects.

---

## 💻 Synopsis

```bash
bloom prebuild [options]
```

---

## ⚙️ Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--clean` | `-c` | `false` | Clean generated artifacts and regenerate route table before prebuilding. |
| `--help` | `-h` | | Print usage information. |

---

## 🔧 Files Mutated by Prebuild

When running in `mode: managed`, the Prebuild Engine performs deterministic AST and XML transformations on:

### 1. `android/app/src/main/AndroidManifest.xml`
* Injects `<uses-permission android:name="..." />` nodes into `<manifest>` root based on activated plugins in `bloom.yaml`:
  * Camera plugin ➔ `android.permission.CAMERA`, `android.permission.RECORD_AUDIO`.
  * Notifications plugin ➔ `android.permission.POST_NOTIFICATIONS`, `android.permission.VIBRATE`.
  * Core runtime ➔ `android.permission.INTERNET`.
* Injects `<intent-filter>` blocks for custom URI schemes (`bloom://`) and App Links domains into `<activity>`.

### 2. `android/app/build.gradle`
* Updates `minSdkVersion` (e.g. `24`) and `targetSdkVersion` (e.g. `34`) based on `platforms.android` in `bloom.yaml`.
* Sets `applicationId` matching active flavor or platform configuration.

### 3. `ios/Runner/Info.plist`
* Injects required Apple Privacy Usage Description strings via XML AST:
  * Camera ➔ `NSCameraUsageDescription`
  * Microphone ➔ `NSMicrophoneUsageDescription`
* Injects `CFBundleURLTypes` for custom URL schemes.

### 4. `web/.well-known/` Domain Verification Files
* Generates `web/.well-known/assetlinks.json` with package name and SHA-256 certificate fingerprints for Android App Links.
* Generates `web/.well-known/apple-app-site-association` with App ID prefix and team ID for iOS Universal Links.

---

## 🛡️ Idempotency Guarantee

The Bloom Prebuild Engine is **strictly idempotent**:
* If a permission, intent filter, or plist key already exists, Prebuild preserves existing configuration without duplicating nodes.
* Custom user entries outside managed Bloom XML blocks are retained untouched.
* Re-running `bloom prebuild` multiple times produces byte-identical results.

---

## 🚪 Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Prebuild synchronization completed successfully across all targets. |
| **`1`** | Failure: malformed XML/plist files or unsupported platform configurations. |
