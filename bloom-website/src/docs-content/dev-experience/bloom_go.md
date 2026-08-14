# 31. Bloom Go Native Mobile Development Client

**Bloom Go** (`apps/bloom_go`) is the companion mobile development shell for Bloom applications. It allows developers to pair physical iOS and Android devices wirelessly with their local development workstation.

---

## 📱 Three Pairing Workflows

Bloom Go connects to your active `bloom dev` session using three distinct workflows:

### 1. Optical QR Code Scanning
Tap **"Scan Terminal QR Code"** in Bloom Go to open the camera viewfinder (powered by `mobile_scanner`). Aim at the ASCII QR code printed by `bloom dev` to connect instantly.

### 2. Zero-Config UDP Auto-Discovery
Bloom Go runs a background UDP listener (`BloomDiscoveryListener`) on port `5354`. If your phone and workstation are on the same Wi-Fi network, active development servers appear automatically in the **"Discovered Dev Servers"** list.

### 3. Manual IP & Port Entry
Enter your computer's local network address manually (e.g. `http://192.168.1.105:8080`) and tap **"Connect"**.

---

## 🖥️ Live Dev Session Screen

Once paired, Bloom Go loads the active project manifest from `/manifest.json`:
* **Project Name & Version:** Verified from `bloom.yaml`.
* **Platform Constraints:** Android Min SDK, iOS Deployment Target, Build Flavors.
* **Discovered Filesystem Routes:** Direct links to launch and preview individual routes.
* **Connected Clients:** Displays all active devices connected to the workstation.

---

## 🪟 Interactive DevTools Overlay (`BloomDevOverlay`)

Tap the floating Bloom badge to open the real-time DevTools inspector overlay:
* **App Info Tab:** Displays active flavor, package name, and boot status.
* **Cache Inspector Tab:** Live list of cached queries with TTL expiration countdowns and a **"Clear Cache"** button.
* **DI Container Tab:** Live dump of registered singleton and factory dependencies.
* **Router Tab:** Shows current route stack and navigation history.

---

## 💡 Important Platform Reality & Notes

Bloom Go connects to the Bloom Dev Server to pair devices, synchronize project manifests, and provide remote DevTools inspection. In the current release, it displays live project manifests and route definitions; executing raw remote JIT Dart bytecode directly on physical hardware without a local debug build is planned for future engine releases.
