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

> See [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md). Anti-patterns A1–A6 apply.

### C1. Environment schema validation is enforced, not just parsed
- **When** `Bloom.boot()` runs and a required env var (e.g. `API_BASE_URL`) is missing.
- **Then** boot fails with a clear error naming the missing key, before any network/DI work.
- **Must not** silently continue with a null/empty value or defer to a later `Null check` crash.
- **Test** boot with an empty env asserts the thrown/printed error names the key.

### C2. `bloom audit` performs a real dependency scan
- **When** run against a project whose `pubspec.lock` contains a known-vulnerable package.
- **Then** lists the CVE/package/version and returns a non-zero exit code.
- **Must not** print "0 vulnerabilities" without querying a data source, nor return 0 when a vuln exists (A1).
- **Test** fixture lockfile with a seeded vulnerable package → assert output + exit code.

### C3. `bloom security scan` actually detects secrets
- **When** a file contains a hardcoded token matching known patterns (AWS key, private-key header, `sk-`/`api_key=`).
- **Then** flags the file:line and returns non-zero.
- **Must not** report "clean" when a seeded secret exists (A1).
- **Test** fixture with a seeded secret string → assert detection + exit code.

### C4. `bloom assets optimize` performs real asset conversion
- **When** run on assets containing PNG/JPEG.
- **Then** WebP variants are written, the bundle references them, and output size is recorded.
- **Must not** print "optimized" while leaving the bundle unchanged (A1).
- **Test** fixture asset → assert WebP files exist and are referenced.

### C5. Build provenance is derived and deterministic
- **When** two builds of identical source run (reproducible build).
- **Then** the provenance manifest's toolchain fields equal the **actual** Flutter/Dart/Bloom versions used (A2), and `sourceHash` is byte-identical across runs.
- **Must not** hardcode `3.27.0`/`1.0.0`, and `sourceHash` must not vary on identical input (A5).
- **Test** build twice → compare manifests; assert toolchain ≠ hardcoded defaults.

### C6. Typed asset references prevent typos at compile time
- **When** code references `Assets.images.nonexistent`.
- **Then** analysis/compilation fails.
- **Test** analyzer test over generated `assets.g.dart`.
