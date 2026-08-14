# Phase 11: Bloom Updates Platform & Runtime Fingerprinting

> **Objective:** Deliver an enterprise-grade Over-The-Air (OTA) update client (`bloom_updates`) with cryptographic native runtime fingerprinting, staged percentage rollouts, update branches, instant rollbacks, and embedded crash recovery fallbacks.

---

## 🏗️ Architecture & Update Pipeline

```text
            Native Runtime Binary
                      │
           Computes Hash Fingerprint
       (Bloom + Flutter + Native Modules)
                      │
                      ▼
           Bloom Updates Server / CDN
                      │
          Matches Runtime Fingerprint?
           ├── YES ➔ Return Compatible Patch Manifest
           └── NO  ➔ Incompatible Native Binary (Reject OTA)
```

---

## 🔐 1. Cryptographic Runtime Fingerprinting

An Over-The-Air code patch that attempts to execute on an incompatible native binary (e.g. calling a camera method before the camera native module is installed) will crash on startup.

Bloom computes a **deterministic SHA-256 Runtime Fingerprint** hashing:
1. `Bloom Framework Version` (e.g. `1.0.0`)
2. `Flutter Engine Revision` & `Dart SDK Version`
3. All registered `Native Module Fingerprints` (from `bloom.lock`)
4. Manifest permissions and platform configuration hashes

```dart
// Generated in build metadata:
const String kBloomRuntimeFingerprint = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
```

When checking for updates, `BloomUpdates` transmits `kBloomRuntimeFingerprint`. The update server **only** delivers patches compiled against the exact same runtime fingerprint.

---

## 📜 2. The `BloomUpdates` Client API

```dart
import 'package:bloom_framework/bloom_updates.dart';

// 1. Check for compatible OTA update
final checkResult = await BloomUpdates.checkForUpdate();

if (checkResult.isAvailable) {
  print('Update ID: ${checkResult.manifest?.id}');
  print('Patch Version: ${checkResult.manifest?.version}');
  print('Release Notes: ${checkResult.manifest?.releaseNotes}');

  // 2. Fetch and stage update assets in background
  final update = await BloomUpdates.fetchUpdate();

  if (update.isReady) {
    // 3. Prompt user or reload immediately
    await BloomUpdates.reload();
  }
}
```

---

## 📊 3. Reactive Update State (`BloomUpdatesState`)

Track the lifecycle of background OTA updates reactively:

| Signal Accessor | Type | Description |
| :--- | :--- | :--- |
| `BloomUpdates.isChecking` | `ReadonlySignal<bool>` | `true` while querying the update server. |
| `BloomUpdates.isAvailable` | `ReadonlySignal<bool>` | `true` if a compatible patch exists. |
| `BloomUpdates.isDownloading`| `ReadonlySignal<bool>` | `true` while streaming patch assets. |
| `BloomUpdates.isReady` | `ReadonlySignal<bool>` | `true` once the patch is verified and staged for the next restart. |
| `BloomUpdates.downloadProgress`| `ReadonlySignal<double>` | Download progress from `0.0` to `1.0`. |
| `BloomUpdates.error` | `ReadonlySignal<Object?>` | Error object if download or verification fails. |

---

## 🎨 4. In-App Update UI Widgets

```dart
// Pre-built reactive in-app update banner
class AppUpdateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (BloomUpdates.isReady.value) {
        return MaterialBanner(
          content: const Text('A new update has been downloaded! Restart to apply.'),
          actions: [
            TextButton(
              onPressed: () => BloomUpdates.reload(),
              child: const Text('RESTART NOW'),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    });
  }
}
```

---

## 🌊 5. Channels, Branches & Staged Rollouts

```yaml
# bloom.yaml
deployment:
  updates:
    channel: production
    branches:
      - main
      - beta
      - hotfix
```

### Staged Percentage Rollouts
Deploy updates gradually to mitigate catastrophic bugs:
```bash
# Rollout to 10% of active users
bloom update publish --channel production --rollout 10

# Increase rollout to 50%
bloom update rollout --id upd_9876 --percentage 50

# Promote to 100%
bloom update rollout --id upd_9876 --percentage 100
```

---

## 🛡️ 6. Instant Rollback & Embedded Crash Recovery

### Command-Line Rollback
```bash
bloom update rollback --channel production
```
Deactivates the faulty update instantly on the CDN, rolling all clients back to the previous stable release.

### Embedded Startup Failure Fallback
If a downloaded OTA patch crashes repeatedly during startup (e.g. 2 consecutive crashes within 5 seconds of launch):
1. Bloom's crash detection watchdog flags the active patch as corrupt.
2. Automatically purges the faulty patch from disk.
3. Restores the clean, embedded base binary bundled with the initial app store release.
4. Reports the startup failure to Bloom Observability.

---

## 🧪 Verification & Acceptance Criteria

> See [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md). Anti-patterns A1–A6 apply.

### C1. Runtime fingerprint parity (invariant A6)
- **When** a patch's `kBloomRuntimeFingerprint` is compared against the running binary.
- **Then** both are derived from **one** canonical source (build-time generated), byte-for-byte equal for a compatible build, and rejected otherwise.
- **Must not** compute the fingerprint independently at runtime vs CLI with different inputs (modules, permissions source, Dart SDK), which silently breaks patch validation.
- **Test** assert runtime `computeHash()` == CLI `computeFingerprint()` for a fixed fixture, and that a differing native module changes the hash.

### C2. Percentage rollouts are deterministic
- **When** a staged rollout targets N% of devices.
- **Then** the same device UUID always lands in the same bucket (stable hash), and the rollout is monotonic.
- **Must not** use a non-persistent or time-varying key (A5).
- **Test** assert a fixed UUID maps to a stable bucket across repeated calls.

### C3. Startup crashes trigger self-healing rollback
- **When** a patch crashes ≥2 times within 5s of launch.
- **Then** the watchdog purges the patch, restores the embedded base binary, and reports the failure.
- **Must not** silently keep serving the corrupt patch (A4).
- **Test** simulate repeated startup crashes → assert rollback + purge + report.

### C4. Background streaming reports real progress
- **When** a patch downloads in the background.
- **Then** progress advances `0.0 → 1.0` and never blocks the UI thread.
- **Must not** report progress without actual download progress (A1).
- **Test** assert progress callback fires with monotonic values during a real download.
