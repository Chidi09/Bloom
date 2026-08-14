# 27. Native Modules & Plugin Architecture

Bloom provides a unified API for interacting with essential mobile platform capabilities.

---

## 📦 Native Modules Overview

| Plugin | Dart Class | Real Ecosystem Dependency | Managed Prebuild Transformations |
| :--- | :--- | :--- | :--- |
| **Secure Storage** | `BloomSecureStorage` | `flutter_secure_storage: ^9.2.4` | Enables Keychain access group & Android backup rules. |
| **Notifications** | `BloomNotifications` | `flutter_local_notifications: ^17.2.4` | Injects `POST_NOTIFICATIONS`, `VIBRATE`, notification channels. |
| **Camera** | `BloomCamera` | `image_picker: ^1.1.2` / `MethodChannel` | Injects `CAMERA`, `RECORD_AUDIO`, `NSCameraUsageDescription`. |
| **Deep Links** | `BloomDeepLinks` | `app_links: ^7.2.1` | Injects `<intent-filter>` schemes and `.well-known` files. |
| **Background Tasks** | `BloomBackground` | `MethodChannel('bloom/background')` | Injects `WAKE_LOCK` and background execution policies. |

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
