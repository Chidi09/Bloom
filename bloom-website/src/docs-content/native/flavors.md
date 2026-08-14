# 29. Multi-Environment Build Flavors

Bloom provides multi-environment flavor management, allowing separate branding, bundle identifiers, backend URLs, and Shorebird OTA channels for development, staging, and production.

---

## 📜 Declaring Flavors in `bloom.yaml`

```yaml
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
```

---

## 🏃 Running with a Flavor

Pass `--flavor <name>` to CLI commands:

```bash
# Run in staging mode
bloom dev --flavor staging

# Deploy OTA patch to staging
bloom deploy --target=android --flavor staging --channel staging
```

---

## ⚙️ Compile-Time Propagation (`BLOOM_FLAVOR`)

When running with a flavor, the Bloom CLI automatically passes:
```bash
--dart-define=BLOOM_FLAVOR=staging
```

`Bloom.boot()` inspects this value:
1. Discovers active flavor from `BLOOM_FLAVOR` environment variable.
2. Loads `.env.staging`.
3. Overrides `Bloom.activeFlavor` to `'staging'`.
4. Applies flavor-specific Shorebird OTA app ID from `bloom.yaml`.

---

## 🔍 Accessing Active Flavor in Code

```dart
import 'package:bloom_framework/bloom.dart';

final activeFlavor = Bloom.activeFlavor; // 'staging', 'development', or 'production'

if (activeFlavor == 'development') {
  // Show debug banner or sandbox tools
}
```
