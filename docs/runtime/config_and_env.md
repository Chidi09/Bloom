# 16. Configuration & Environment (`BloomEnv` & `BloomConfig`)

Bloom provides typed configuration parsing and multi-stage dot-env resolution with strict precedence ordering.

---

## 📄 Environment Variable Precedence

When `Bloom.boot()` loads environment variables, it merges sources in the following priority order (highest to lowest):

```text
 1. Process Environment Variables / Flutter --dart-define flags
 2. Flavor-specific environment file (e.g. .env.staging)
 3. Local machine overrides (.env.local)
 4. Base environment file (.env)
 5. Compile-time fallback defaults
```

---

## 🔍 Accessing Environment Variables (`BloomEnv`)

Use `BloomEnv` static accessors anywhere in your application:

```dart
import 'package:bloom_framework/bloom.dart';

// Required String (throws StateError if missing)
final apiUrl = BloomEnv.get('API_BASE_URL');

// Optional String with fallback
final port = BloomEnv.getOrDefault('PORT', '8080');

// Optional String (returns null if missing)
final apiKey = BloomEnv.getOrNull('STRIPE_KEY');

// Strongly-typed Parsers
final isDebug = BloomEnv.getBool('DEBUG_MODE', defaultValue: false);
final maxRetries = BloomEnv.getInt('MAX_RETRIES', defaultValue: 3);
final timeoutSec = BloomEnv.getDouble('TIMEOUT_SECONDS', defaultValue: 15.0);
```

---

## 📜 Strongly-Typed Application Manifest (`BloomConfig`)

During boot, Bloom loads and parses `bloom.yaml` into a typed `BloomConfig` instance available in DI or via `Bloom.config`:

```dart
final config = Bloom.config;

print(config.name);                               // 'bloom_shop'
print(config.version);                            // '1.0.0'
print(config.platforms.androidMinSdk);            // 24
print(config.platforms.iosMinVersion);            // '15.0'
print(config.deepLinks.enabled);                  // true
print(config.deployment.shorebird.appId);         // 'uuid...'
```

### Parsing Custom YAML Configurations
```dart
const customYaml = '''
name: sample_service
version: 2.0.0
features:
  data: true
''';

final parsedConfig = BloomConfig.fromYaml(customYaml);
```
