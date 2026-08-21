# `bloom deploy` CLI Reference Manual

Orchestrates **Over-The-Air (OTA) Code Push** deployments and production binary release builds powered by Shorebird.

---

## 1. Synopsis

```bash
bloom deploy [options]
```

---

## 2. Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--platform` | `-p` | `android` | Target release platform (`android`, `ios`). |
| `--release-version`| | Auto-detected | Specific app version string to patch (e.g. `1.0.0+1`). |
| `--track` | `-t` | `production` | Deployment track or channel (`production`, `staging`, `internal`). |
| `--force` | | `false` | Bypasses uncommitted git working tree check. |
| `--help` | `-h` | | Print usage information. |

---

## 3. Deployment Workflow

1. **Working Tree Verification**: Verifies that your git repository is clean and on an authorized release branch.
2. **Release Fingerprinting**: Computes a cryptographic checksum of Dart assets and native binaries.
3. **Patch Compilation**: Compiles the modified Dart AOT bytecode snapshot.
4. **Shorebird Cloud Dispatch**: Uploads the patch to Shorebird servers for instant OTA delivery to active users on app launch.

```bash
# Deploy an instant OTA hotfix to production Android users
bloom deploy --platform android --track production
```
