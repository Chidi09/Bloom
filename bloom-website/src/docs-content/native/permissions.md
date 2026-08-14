# 26. Runtime Permission Management (`BloomPermissions`)

Bloom provides a cross-platform runtime permission abstraction powered by `permission_handler` under the hood.

---

## 📋 Supported Permission Types

`BloomPermission` enum defines standard device capability permissions:

| Permission | Android Mapping | iOS Mapping |
| :--- | :--- | :--- |
| `BloomPermission.camera` | `Manifest.permission.CAMERA` | `NSCameraUsageDescription` |
| `BloomPermission.photos` | `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` | `NSPhotoLibraryUsageDescription` |
| `BloomPermission.microphone` | `Manifest.permission.RECORD_AUDIO` | `NSMicrophoneUsageDescription` |
| `BloomPermission.notifications`| `Manifest.permission.POST_NOTIFICATIONS` | Push Notification Authorization |
| `BloomPermission.location` | `ACCESS_FINE_LOCATION` | `NSLocationWhenInUseUsageDescription` |
| `BloomPermission.storage` | `WRITE_EXTERNAL_STORAGE` | Document Storage |

---

## 🚦 Permission Statuses & Normalization

`BloomPermissionStatus` normalizes platform-specific statuses into a consistent state machine:

| Status | Meaning |
| :--- | :--- |
| `granted` | User has granted permission (includes iOS provisional notifications). |
| `denied` | Permission is denied but can be requested again via system dialog. |
| `permanentlyDenied`| User has selected "Don't ask again" or disabled via device settings. |
| `restricted` | Permission restricted by OS parental controls or enterprise MDM profile. |
| `limited` | iOS Photo Library limited authorization. |

---

## ⚡ Checking and Requesting Permissions

```dart
import 'package:bloom_framework/bloom.dart';

// 1. Check current status without prompting user
final status = await BloomPermissions.check(BloomPermission.camera);

if (status == BloomPermissionStatus.granted) {
  logger.info('Camera access is ready.');
} else if (status == BloomPermissionStatus.permanentlyDenied) {
  // Direct user to native system settings screen
  await BloomPermissions.openAppSettings();
} else {
  // 2. Request permission from user via system dialog
  final requestStatus = await BloomPermissions.request(BloomPermission.camera);
  if (requestStatus == BloomPermissionStatus.granted) {
    logger.info('Camera access granted by user.');
  }
}
```
