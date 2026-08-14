# Phase 14: Professional Tooling, Typed Config & Security Audit

> **Objective:** Deliver enterprise-grade configuration tooling (`bloom.config.dart`), environment schemas, feature flag management, asset optimization pipelines, security audits (`bloom audit`), secret scanning, and reproducible build provenance.

---

## 🏗️ Professional Tooling Topology

```text
       bloom.config.dart             Environment Schema
       (Typed Config)               (Validated Properties)
              │                              │
              └──────────────┬───────────────┘
                             ▼
                 Bloom Compilation Pipeline
                             │
     ┌───────────────────────┼───────────────────────┐
     ▼                       ▼                       ▼
Asset Optimizer        Security Auditor      Build Provenance
(WebP, Font subset)    (CVE, Secret scan)   (Reproducible Hash)
```

---

## 📜 1. Type-Safe Configuration (`bloom.config.dart`)

Alongside declarative `bloom.yaml`, Bloom supports programmatic, strongly-typed configuration in Dart for conditional environments and computed values:

```dart
// bloom.config.dart
import 'package:bloom_framework/bloom_config.dart';

const config = BloomAppConfig(
  name: 'bloom_shop',
  version: '1.0.0',
  mode: NativeMode.managed,
  platforms: PlatformsConfig(
    android: AndroidPlatform(minSdk: 24, targetSdk: 34),
    ios: IosPlatform(minVersion: '15.0'),
  ),
  plugins: [
    BloomPlugin('secure-storage'),
    BloomPlugin('camera'),
    BloomPlugin('notifications', config: {
      'androidChannelId': 'shop_alerts',
    }),
  ],
);
```

---

## 🔍 2. Validated Environment Schemas

Enforce strict typing and required fields on environment variables:

```dart
// lib/config/environment.dart
import 'package:bloom_framework/bloom.dart';

class EnvironmentSchema extends BloomEnvironmentSchema {
  late final apiUrl = requireString('API_BASE_URL');
  late final stripePublishableKey = requireString('STRIPE_KEY');
  late final debugTelemetry = optionalBool('ENABLE_TELEMETRY', defaultValue: false);
  late final maxRetries = optionalInt('MAX_RETRIES', defaultValue: 3);
}

// Validated during Bloom.boot()
final env = BloomEnv.validate(EnvironmentSchema());
```

---

## 🚩 3. Dynamic Feature Flags

Manage feature rollouts locally or via remote toggles:

```dart
// Check feature flag status
if (Bloom.features.isEnabled('new_checkout_flow')) {
  BloomRouter.go('/checkout-v2');
} else {
  BloomRouter.go('/checkout');
}
```

---

## 🎨 4. Asset Optimization Pipeline (`bloom assets`)

### Image Compression & WebP Conversion
Automatically compresses PNGs and JPEGs, generating optimized WebP variants:
```bash
bloom assets optimize
```

### Unused Asset Analyzer
Scans Dart code and route templates to detect orphaned images, fonts, and icons:
```bash
bloom assets analyze
```
**Output:**
```text
🔍 Analyzing asset references across lib/...

⚠ 3 Unused Assets Detected (Saved: 4.2 MB):
  • assets/images/old_banner.png (2.1 MB)
  • assets/icons/legacy_cart.svg (45 KB)
  • assets/fonts/CustomFont-ExtraBold.ttf (2.0 MB)
```

### Typed Asset Reference Generator
Generates strongly typed asset constants (`lib/generated/assets.g.dart`):
```dart
// Before:
Image.asset('assets/images/logo.png')

// After (Type-Safe & Autocompleted):
Image.asset(Assets.images.logo)
```

---

## 🛡️ 5. Security & Dependency Audit (`bloom audit`)

Scans all Dart and native dependencies for known CVE vulnerabilities and license risks:

```bash
bloom audit
```

**Output:**
```text
🛡️ Bloom Security Diagnostic

✔ 0 Critical Vulnerabilities
✔ 0 High Severity CVEs
✔ 0 Weak Cryptographic Primitives detected
✔ License Compliance: 100% Permissive (MIT, Apache-2.0, BSD-3)
```

---

## 🔑 6. Secret Detection & Sanitization

Prevents hardcoded API tokens, private keys, or certificates from entering version control or production logs:

```bash
bloom security scan
```

---

## 📜 7. Build Provenance & Reproducibility

Every compiled production release embeds a cryptographically signed Build Provenance manifest:

```json
{
  "buildId": "bld_987654321",
  "timestamp": "2026-08-14T12:00:00Z",
  "builder": "GitHub Actions (Runner: ubuntu-22.04)",
  "commit": "a4c1157",
  "toolchain": {
    "bloomVersion": "1.0.0",
    "flutterVersion": "3.27.0",
    "dartVersion": "3.6.0"
  },
  "sourceHash": "sha256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"
}
```

---

## 🧪 Verification & Acceptance Criteria

1. `BloomEnv.validate()` catches missing environment variables during startup with clear error messages.
2. `bloom assets optimize` converts assets to WebP and strips unused binary assets from output bundles.
3. `bloom audit` flags vulnerable dependencies and unlicensed native libraries.
4. Typed asset references (`Assets.images.*`) provide compile-time safety against typos.
