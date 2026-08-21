# `bloom prebuild` CLI Reference Manual

Idempotently synchronizes native Android and iOS configuration files (`AndroidManifest.xml`, `Info.plist`, entitlements, deep links) based on declarations in your `bloom.yaml` manifest.

---

## 1. Synopsis

```bash
bloom prebuild [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--clean` | Cleans previous prebuild artifacts before regenerating. | `false` |
| `--platform` | Restricts synchronization to a specific platform (`android`, `ios`). | `all` |
| `--help` | Print usage information. | |

---

## 2. Managed Declarations in `bloom.yaml`

Instead of manually editing platform XML and plist files, declare native requirements in `bloom.yaml`:

```yaml
name: bloom_app
version: 1.0.0+1

permissions:
  - camera
  - location_when_in_use
  - notifications

deep_links:
  scheme: bloom
  hosts:
    - app.bloom.dev
```

When `bloom prebuild` executes:
* Injects `<uses-permission android:name="android.permission.CAMERA" />` into `android/app/src/main/AndroidManifest.xml`.
* Injects `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription` into `ios/Runner/Info.plist`.
* Sets up Android Intent Filters and iOS Universal Links (`CFBundleURLTypes`).
