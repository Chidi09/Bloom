# 34. Over-The-Air (OTA) Updates & Shorebird Integration

Bloom provides first-class Over-The-Air (OTA) code-push integration powered by the Shorebird engine (`shorebird_code_push: ^2.0.7`). Deploy bug fixes and feature updates to users instantly without waiting for App Store or Google Play review.

---

## 🏗️ Architecture

```text
                  Developer Machine
                         │
              bloom deploy --target=android
                         │
                         ▼
               Shorebird Cloud Engine
                         │
       ┌─────────────────┴─────────────────┐
       ▼                                   ▼
 Installed App Binary               Installed App Binary
   (Vanilla Build)                    (Shorebird Engine)
       │                                   │
 OTA Unavailable                     BloomOTA.checkForUpdate()
                                           │
                                     Patch Staged
                                           │
                                     Next App Launch
                                     (Updated Instantly)
```

---

## ⚡ Using `BloomOTA` at Runtime

### 1. Initializing OTA Controller
`Bloom.boot()` initializes `BloomOTA` automatically when `deployment.shorebird.enabled` is `true`. You can also initialize it imperatively:

```dart
import 'package:bloom_framework/bloom.dart';

await BloomOTA.initialize(channel: 'production');

print('Running on Shorebird Engine: ${BloomOTA.isAvailable}');
print('Current Installed Patch: ${BloomOTA.currentPatchNumber ?? "Base Release"}');
```

---

### 2. Checking for Updates

```dart
final hasUpdate = await BloomOTA.checkForUpdate();

if (hasUpdate) {
  logger.info('A new OTA patch is available for download.');
}
```

---

### 3. Downloading and Staging Patches

```dart
final success = await BloomOTA.downloadUpdate();

if (success) {
  logger.info('Patch downloaded successfully. It will apply on the next app restart.');
}
```

---

### 4. Listening to Status Changes (`onStatusChanged`)

Build custom in-app update banners by listening to `BloomOTA.onStatusChanged`:

```dart
BloomOTA.onStatusChanged.listen((status) {
  switch (status) {
    case BloomOtaStatus.checkingForUpdate:
      print('Checking Shorebird servers for patches...');
      break;
    case BloomOtaStatus.updateAvailable:
      print('New code patch available!');
      break;
    case BloomOtaStatus.downloading:
      print('Downloading patch assets in background...');
      break;
    case BloomOtaStatus.updateReady:
      print('Patch ready! Restart the app to apply changes.');
      break;
    case BloomOtaStatus.upToDate:
      print('App is running the latest available patch.');
      break;
    case BloomOtaStatus.error:
      print('Failed to download or apply OTA patch.');
      break;
    case BloomOtaStatus.idle:
      break;
  }
});
```

---

## 🚀 Releasing vs Patching

| Operation | Command | When to Use |
| :--- | :--- | :--- |
| **Base Release** | `bloom deploy --release --target=android` | When native code, Android/iOS manifest permissions, or Gradle dependencies have changed. |
| **OTA Code Patch** | `bloom deploy --patch --target=android` | For standard Dart code, UI tweaks, business logic fixes, and new routes. |
