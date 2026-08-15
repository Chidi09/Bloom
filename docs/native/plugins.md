# 27. Native Modules & Plugin Architecture

Bloom provides a unified API for interacting with essential mobile platform capabilities.

---

## 📦 Native Modules Overview

All plugins are registered in `BloomPluginCatalog`. Canonical plugin IDs use lowercase underscore naming (e.g. `secure_storage`, `background_tasks`), though CLI commands also accept hyphenated names (e.g. `secure-storage`, `background-tasks`) and normalize them to canonical IDs.

| Plugin ID | Dart Class | Real Ecosystem Dependency | Managed Prebuild Transformations |
| :--- | :--- | :--- | :--- |
| `secure_storage` | `BloomSecureStorage` | `flutter_secure_storage: ^9.2.4` | None (managed directly by dependency). |
| `notifications` | `BloomNotifications` | `flutter_local_notifications: ^17.2.4` | Injects `android.permission.POST_NOTIFICATIONS`, `android.permission.VIBRATE`. |
| `camera` | `BloomCamera` | `image_picker: ^1.1.2` / `MethodChannel` | Injects `android.permission.CAMERA`, `android.permission.RECORD_AUDIO`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`. |
| `location` | `BloomPermissions` | `permission_handler: ^11.3.1` / `MethodChannel` | Injects `android.permission.ACCESS_FINE_LOCATION`, `android.permission.ACCESS_COARSE_LOCATION`, `NSLocationWhenInUseUsageDescription`. |
| `deep_links` | `BloomDeepLinks` | `app_links: ^7.2.1` | Injects Android `<intent-filter>` schemes and iOS `CFBundleURLTypes`, and generates `.well-known` domain verification files (`assetlinks.json`, `apple-app-site-association`). |
| `background_tasks` | `BloomBackground` | `MethodChannel('bloom/background')` | Injects `android.permission.WAKE_LOCK`, `android.permission.FOREGROUND_SERVICE`. |
| `auth` | `BloomAuth` | Framework-level feature | None (framework-level feature, carries no platform transformations). |
| `storage` | `BloomStorageAdapter` | Framework-level feature | None (framework-level feature, carries no platform transformations). |

---

## 🔒 1. Secure Storage (`BloomSecureStorage`)
Interacts with hardware-backed Keystore on Android and iOS Keychain:
```dart
final storage = BloomSecureStorage();
await storage.write('auth_token', 'jwt_secret_token');
final token = await storage.read('auth_token');
```

---

## 🔔 2. Local Notifications (`BloomNotifications`)
Initializes system notification dispatching with Android notification channels:
```dart
// 1. Initialize notification system
await BloomNotifications.initialize(
  defaultAndroidChannelId: 'shop_alerts',
  defaultAndroidChannelName: 'Shop Alerts',
);

// 2. Dispatch a notification
await BloomNotifications.show(
  id: 101,
  title: 'Order Shipped!',
  body: 'Your package is on its way.',
);
```

---

## 📸 3. Camera Capture (`BloomCamera`)
Requests runtime camera permissions and launches native camera capture interface:
```dart
final hasCamera = await BloomCamera.initialize();
if (hasCamera) {
  final photo = await BloomCamera.takePicture();
  if (photo != null) {
    print('Photo captured at: ${photo.path} (${photo.bytes.length} bytes)');
  }
}
```

---

## 💡 Important Platform Reality & Notes

* **`BloomSecureStorage` & `BloomNotifications`:** Wrap industry-standard, fully functional production plugins (`flutter_secure_storage` and `flutter_local_notifications`).
* **`BloomCamera`:** Uses real `image_picker` when available or forwards calls via `MethodChannel('bloom/camera')`. Note that custom hardware method channels require appropriate native host drivers if not using standard image picking.
* **`BloomBackground`:** Wraps `MethodChannel('bloom/background')` for registering background worker tasks.
* **`auth` & `storage`:** Catalogued in `BloomPluginCatalog` to allow CLI project configuration (`bloom add auth`, `bloom add storage`), but are framework-level features (`BloomAuth`, `BloomStorageAdapter`) rather than native plugins and carry no platform prebuild transformations.
