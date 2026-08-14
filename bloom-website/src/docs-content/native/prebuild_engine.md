# 28. Native Prebuild Engine

The Bloom Prebuild Engine transforms declarative definitions in `bloom.yaml` into low-level platform manifest configurations, eliminating manual XML/plist editing.

---

## ⚙️ How Prebuild Works

When `bloom prebuild` or `bloom dev` runs, the Prebuild Engine performs AST parsing on the project's native build directories:

```text
               bloom.yaml
                   │
                   ▼
         Bloom Prebuild Engine
                   │
    ┌──────────────┼──────────────┐
    ▼              ▼              ▼
 Android       iOS Runner       Web
 Manifest     Info.plist    .well-known
```

---

## 🤖 Android Transformations (`AndroidManifest.xml`)

* **XML AST Parser:** Reads `android/app/src/main/AndroidManifest.xml` via `package:xml`.
* **Permission Injection:** Checks existing `<uses-permission>` nodes and injects missing entries:
  ```xml
  <manifest xmlns:android="http://schemas.android.com/apk/res/android" ...>
      <uses-permission android:name="android.permission.INTERNET" />
      <uses-permission android:name="android.permission.CAMERA" />
      <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
      ...
  ```
* **Intent Filter Generation:** Injects `<intent-filter>` blocks for deep link schemes (`bloom://`) and App Link domains (`android:autoVerify="true"`).
* **SDK Version Sync:** Automatically configures `minSdkVersion` and `targetSdkVersion` in `android/app/build.gradle`.

---

## 🍏 iOS Transformations (`Info.plist`)

* **Plist AST Synchronization:** Parses `ios/Runner/Info.plist` as XML.
* **Privacy Descriptions:** Injects human-readable purpose strings for sensitive device sensors:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>This application requires camera access to scan QR codes and capture photos.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>This application requires microphone access to record audio.</string>
  ```
* **URL Types:** Injects `CFBundleURLSchemes` entries for custom URI schemes.

---

## 🌐 Domain Verification (`.well-known`)

For App Links (Android) and Universal Links (iOS), Prebuild automatically generates domain association files inside `web/.well-known/`:

### 1. `web/.well-known/assetlinks.json` (Android)
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "dev.bloom.shop",
      "sha256_cert_fingerprints": [
        "14:6D:E9:7F:0E:52:D7:1E:27:52:83:B6:B7:A0:64:13:E4:E8:1B:6F"
      ]
    }
  }
]
```

### 2. `web/.well-known/apple-app-site-association` (iOS)
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "A1B2C3D4E5.dev.bloom.shop",
        "paths": ["*"]
      }
    ]
  }
}
```
