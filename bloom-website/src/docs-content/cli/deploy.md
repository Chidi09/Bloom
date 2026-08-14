# `bloom deploy`

Orchestrates Over-The-Air (OTA) code-push patches and full binary base releases powered by the Shorebird engine.

---

## 💻 Synopsis

```bash
bloom deploy [options]
```

---

## ⚙️ Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--channel` | `-c` | `production` | Target release channel (e.g. `production`, `staging`, `preview`). |
| `--target` | `-t` | `android` | Target platform to patch or release. Valid values: `android`, `ios`, `aar`, `ios-framework`. |
| `--flavor` | `-f` | `null` | Build flavor to deploy (e.g. `staging`, `production`). Injects `--flavor <name>` and `BLOOM_FLAVOR=<name>`. |
| `--patch` | | `true` | Deploy an Over-The-Air (OTA) code-push patch to existing installed app binaries. |
| `--release` | | `false` | Build and publish a full base binary release (submits new base engine to Shorebird). |
| `--dry-run` | | `false` | Validates configuration, generates `shorebird.yaml`, and outputs the planned deployment command without executing it. |
| `--app-id` | | `null` | Explicit Shorebird App ID override. |
| `--prebuild` | | `true` | Run native prebuild platform synchronization prior to deploying. |
| `--help` | `-h` | | Print usage information. |

---

## 🚀 Examples

### 1. Dry Run Validation
Validate configuration, flavor mapping, and command arguments in CI/CD without executing:
```bash
bloom deploy --dry-run --target=android --channel=staging --flavor=staging
```

### 2. Deploying a Patch to Production
Publish an instant Dart code patch over-the-air:
```bash
bloom deploy --target=android --channel=production
```

### 3. Publishing a Base Release
Build a new binary base version when native dependencies or plugins have changed:
```bash
bloom deploy --release --target=android --flavor=production
```

---

## 📋 Shorebird Prerequisites

1. **Install Shorebird CLI:**
   ```bash
   curl --proto "=https" --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
   ```
2. **Authenticate with Shorebird:**
   ```bash
   shorebird login
   ```
3. **Configure `bloom.yaml`:**
   ```yaml
   deployment:
     shorebird:
       enabled: true
       app_id: "your-shorebird-app-uuid"
   ```

---

## 🚪 Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Deployment or dry-run validation succeeded. |
| **`1`** | Failure: Invalid target platform, undefined flavor, missing Shorebird CLI binary during real deploy, or compilation error. |
