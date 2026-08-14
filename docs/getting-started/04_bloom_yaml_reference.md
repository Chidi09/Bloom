# 4. `bloom.yaml` Full Specification & Reference

`bloom.yaml` is the centralized manifest for configuring your Bloom project. It replaces disparate platform configuration files with a typed, declarative schema.

---

## 📜 Full `bloom.yaml` Example

```yaml
schema: 1
name: bloom_shop
version: 1.0.0
description: "High-performance reactive mobile storefront."
mode: managed # 'managed' or 'bare'

platforms:
  android:
    min_sdk: 24
    target_sdk: 34
    package: dev.bloom.shop
  ios:
    minimum_version: "15.0"
    bundle_identifier: dev.bloom.shop
  web:
    title: "Bloom Shop Online"

features:
  routing: true
  state: true
  data: true
  native: true

environment:
  files:
    - .env
    - .env.local

flavors:
  development:
    app_name: "Bloom Shop (Dev)"
    app_id: dev.bloom.shop.dev
    env_file: .env.development
  staging:
    app_name: "Bloom Shop (Staging)"
    app_id: dev.bloom.shop.staging
    env_file: .env.staging
  production:
    app_name: "Bloom Shop"
    app_id: dev.bloom.shop
    env_file: .env.production

plugins:
  - secure-storage
  - camera
  - notifications:
      android_channel_id: shop_alerts
      importance: high
  - background-tasks

deep_links:
  enabled: true
  schemes:
    - bloomshop
    - bloom
  domains:
    - host: shop.bloom.dev
      sha256_cert_fingerprints:
        - "14:6D:E9:7F:0E:52:D7:1E:27:52:83:B6:B7:A0:64:13:E4:E8:1B:6F"
      app_store_team_id: "A1B2C3D4E5"
  routes:
    /products/:id: /product-detail
    /orders/:id: /order-status

deployment:
  shorebird:
    enabled: true
    app_id: "b2d88194-6d9b-4a5c-9c71-081e6a71e204"
    auto_check_update: true
    flavors:
      staging: "staging-uuid-1111"
      production: "prod-uuid-2222"
```

---

## 📋 Comprehensive Schema Reference

### Top-Level Fields

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `schema` | `int` | `1` | Configuration schema version. Currently `1`. |
| `name` | `string` | `bloom_app` | Project package identifier. Must be lowercase snake_case. |
| `version` | `string` | `0.1.0` | Semantic application version (e.g. `1.0.0+1`). |
| `description`| `string` | `""` | Human-readable project description. |
| `mode` | `string` | `managed` | Native configuration mode: `managed` (Bloom Prebuild maintains native XML/plist files) or `bare` (manual developer management). |

---

### `platforms` Block

Configures native target constraints across Android, iOS, and Web.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `platforms.android.min_sdk` | `int` | `24` | Android minimum SDK version (`minSdkVersion`). |
| `platforms.android.target_sdk`| `int` | `34` | Android target SDK version (`targetSdkVersion`). |
| `platforms.android.package` | `string` | `null` | Android Application ID / Package Name (e.g. `dev.bloom.app`). |
| `platforms.ios.minimum_version`| `string` | `"15.0"` | iOS Deployment Target (`IPHONEOS_DEPLOYMENT_TARGET`). |
| `platforms.ios.bundle_identifier`| `string` | `null` | iOS Bundle Identifier (e.g. `dev.bloom.app`). |
| `platforms.web.title` | `string` | `"Bloom App"` | Default HTML document `<title>` tag for web builds. |

---

### `features` Block

Toggles core framework subsystems.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `features.routing` | `bool` | `true` | Enables automatic filesystem routing generator. |
| `features.state` | `bool` | `true` | Enables fine-grained Signals reactivity layer. |
| `features.data` | `bool` | `false` | Enables Bloom Data query/mutation cache and offline queue. |
| `features.native` | `bool` | `false` | Enables native plugin synchronization in prebuild. |

---

### `environment` Block

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `environment.files` | `List<string>` | `['.env', '.env.local']` | List of dot-env files to load at boot in sequential priority. |

---

### `flavors` Block

Declares multi-environment build variants.

| Sub-Key | Type | Description |
| :--- | :--- | :--- |
| `app_name` | `string` | Display name of the application for this flavor. |
| `app_id` | `string` | Native Bundle ID / Application ID override for this flavor. |
| `env_file` | `string` | Specific `.env` file to load when `--flavor <name>` is active. |
| *(custom)* | `dynamic` | Arbitrary custom metadata accessible via `BloomConfig.flavors['name'].custom`. |

---

### `plugins` Block

List of native plugins activated in `managed` mode. Can be specified as a list of strings or key-value maps:
* `secure-storage` — Injects Keychain and EncryptedSharedPreferences entitlements.
* `camera` — Injects `android.permission.CAMERA` and `NSCameraUsageDescription`.
* `notifications` — Injects `POST_NOTIFICATIONS`, `VIBRATE`, and notification channels.
* `background-tasks` — Injects background wake locks and lifecycle delegates.

---

### `deep_links` Block

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `deep_links.enabled` | `bool` | `false` | Activates deep linking engine. |
| `deep_links.schemes` | `List<string>` | `[]` | Custom URI schemes (e.g. `myapp://`). |
| `deep_links.domains` | `List<dynamic>` | `[]` | HTTPS domains for Android App Links and iOS Universal Links. |
| `deep_links.routes` | `Map<string, string>` | `{}` | Direct URI path to route URL alias mappings. |

---

### `deployment.shorebird` Block

Controls Over-The-Air (OTA) code push patching powered by Shorebird.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `shorebird.enabled` | `bool` | `false` | Enables OTA update engine. |
| `shorebird.app_id` | `string` | `"auto"` | Primary Shorebird App UUID from console. |
| `shorebird.auto_check_update`| `bool` | `true` | Automatically checks for OTA updates in background during `Bloom.boot()`. |
| `shorebird.flavors` | `Map<string, string>` | `{}` | Shorebird App IDs per build flavor. |
