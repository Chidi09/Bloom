# 07. Native Architecture & Plugins

## 1. Native Philosophy: Managed vs Bare

Bloom eliminates repetitive native boilerplate (configuring permissions, bundle IDs, splash screens, launcher icons, deep links) without trapping advanced developers in an opaque walled garden.

```text
┌─────────────────────────────────────────────────────────────┐
│                        Managed Mode                         │
│  • Bloom manages android/ and ios/ configuration files.     │
│  • bloom.yaml is the single source of truth.                │
│  • Running `bloom prebuild` generates platform manifests.   │
└─────────────────────────────────────────────────────────────┘
                               ▲
                               │ Developers can transition at any time
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                          Bare Mode                          │
│  • Developer directly modifies android/ and ios/ projects.  │
│  • Bloom acts as a non-destructive assistant.               │
│  • Standard Flutter platform channels and Podfiles remain.  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Plugin Configuration in `bloom.yaml`

Instead of manually editing `AndroidManifest.xml`, `Info.plist`, and `Podfile`, plugins declare their requirements declaratively:

```yaml
# bloom.yaml
plugins:
  - camera:
      camera_permission: "Allow $(PRODUCT_NAME) to access your camera to scan documents"
      microphone_permission: "Allow audio recording for video notes"

  - notifications:
      enabled: true
      ios:
        request_on_boot: true
      android:
        default_icon: "ic_notification"
        channels:
          - id: reminders
            name: "Task Reminders"
            importance: high

  - secure_storage:
      ios_accessibility: first_unlock
      android_encrypted_shared_preferences: true
```

---

## 3. The Plugin Lifecycle & Prebuild Pipeline

```text
Read bloom.yaml
      ↓
Validate Plugin Configuration Schemas
      ↓
Resolve Plugin Prebuild Hooks
      ↓
Execute Platform Transformations:
  ├── Android: Merge AndroidManifest.xml, build.gradle, res/
  └── iOS: Update Info.plist, entitlements, Podfile, project.pbxproj
      ↓
Verify Native File Integrity
      ↓
Execute Flutter Build / Run
```

---

## 4. Initial Reference Modules (v0.3)

Bloom ships with three core reference modules designed to prove the plugin configuration contract:

### 4.1 Secure Storage (`bloom_secure_storage`)
Provides encrypted key-value storage using Keychain (iOS) and EncryptedSharedPreferences (Android).

```dart
final storage = inject<BloomSecureStorage>();
await storage.write('auth_token', token);
final token = await storage.read('auth_token');
```

### 4.2 Notifications (`bloom_notifications`)
Provides cross-platform push and local notifications with pre-configured notification channels.

```dart
final notifications = inject<BloomNotifications>();
await notifications.show(
  title: 'Welcome to Bloom',
  body: 'Your application is ready.',
);
```

### 4.3 Camera (`bloom_camera`)
Provides camera preview, barcode scanning, and image capture with automated permission prompts.

```dart
final camera = inject<BloomCamera>();
final photo = await camera.takePicture();
```

---

## 5. Native Modules Roadmap

Following the stabilization of reference modules, subsequent modules follow the same standardized declarative contract:

| Category | Modules |
| :--- | :--- |
| **Hardware & Sensors** | Biometrics, Location, Sensors (Accelerometer/Gyro), Haptics |
| **Media & Device** | Filesystem, Clipboard, Connectivity, Battery |
| **System Integrations** | Contacts, Calendar, Background Tasks, Audio Session |
