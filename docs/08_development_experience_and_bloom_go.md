# 08. Development Experience, Bloom Go & OTA

## 1. Stage 1: Modern Terminal DX (`bloom dev`)

`bloom dev` replaces the cluttered default output of `flutter run` with an interactive, beautiful terminal dashboard tailored for fast feedback loops:

```text
┌─────────────────────────────────────────────────────────────┐
│  BLOOM DEV v0.1.0                          • Port 8080      │
│                                                             │
│  › Active Devices:                                          │
│    [1] Android Emulator • Pixel 8 (API 34)                  │
│    [2] iOS Simulator    • iPhone 15 Pro (iOS 17.4)          │
│    [3] Chrome (Web)     • http://localhost:8080             │
│                                                             │
│  › Shortcuts:                                               │
│    [r] Hot Reload          [R] Hot Restart                  │
│    [o] Open DevTools       [d] Toggle Device Selector       │
│    [c] Clear Console       [q] Quit Session                 │
│                                                             │
│  › Recent Logs:                                             │
│    10:42:01 [AUTH] Session restored for user_id: 8492       │
│    10:42:02 [DATA] Query ['users', '8492'] cached in memory │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Wireless Development (`bloom dev --wireless`)

Eliminates the need to remain tethered via USB cables during mobile testing:

```text
Initial USB Connection
         ↓
Pair Device over Local Subnet (`bloom dev --wireless`)
         ↓
Auto-detect Wi-Fi IP and Port
         ↓
Subsequent Sessions Connect Wirelessly
```

---

## 3. QR Code Installation & Dev Hosting

For rapid physical device testing without store submissions:

```bash
bloom build --dev
```

1. Compiles a development build with debug metadata.
2. Spawns a local, secure artifact HTTP server.
3. Renders an ASCII QR code directly in the terminal.
4. Scanning the QR on iOS/Android installs the development build directly.

---

## 4. Bloom Dev Client & Bloom Go

### 4.1 What Bloom Go Actually Is
Bloom Go is an Expo-Go-style universal development shell for Flutter. It is a pre-compiled native binary containing:
* The Flutter Engine
* The Bloom Framework runtime
* Approved standard Bloom native modules (Camera, Storage, Notifications, Biometrics, etc.)
* A JIT/debug socket receiver

```text
Bloom Project Code (Dart)
         ↓
Bloom Dev Server (Local Machine)
         ↓
WebSocket / TCP JIT Stream
         ↓
Bloom Go Native App (Mobile Device)
         ↓
Instant Execution (No local Xcode/Android Studio required for pure Dart changes)
```

### 4.2 Handling Custom Native Code (Bloom Dev Client)
When an app requires a proprietary native SDK not included in standard Bloom Go, the developer runs:

```bash
bloom run --device
```

This compiles a customized **Bloom Dev Client** incorporating the project's exact native plugins, which then connects to the local Bloom Dev server for instant updates.

---

## 5. Bloom Go 7-Step Implementation Sequence

To avoid premature architectural overreach, Bloom Go is executed in seven structured milestones:

```text
Step 1: Build `bloom dev` interactive terminal orchestration (v0.1)
   ↓
Step 2: Build QR-based project and local device discovery (v0.5)
   ↓
Step 3: Prototype a standalone native Bloom Go shell (v0.6)
   ↓
Step 4: Connect Dart VM Service / Debug Runtime bridge (v0.6)
   ↓
Step 5: Stream and execute dynamic Bloom bundle code (v0.6)
   ↓
Step 6: Implement Dev Client native plugin registry & compilation (v0.7)
   ↓
Step 7: Package and distribute Bloom Go to App Store & Google Play (v1.0)
```

---

## 6. Over-The-Air (OTA) Updates (`bloom deploy`)

Bloom does **not** reinvent a proprietary OTA engine from scratch. Instead, Bloom integrates with **Shorebird**, the industry-standard code-push solution for Flutter:

```bash
bloom deploy --channel production
```

```text
bloom deploy
     ↓
Validate Environment & Build Config
     ↓
Trigger Shorebird Engine Patch / Release Workflow
     ↓
Publish Artifacts to Distribution Channels
```
