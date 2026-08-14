# `bloom doctor`

Runs automated health checks on your local developer machine, evaluating toolchain availability, platform SDK versions, Shorebird OTA prerequisites, local network interfaces, and project-level configuration integrity.

---

## 💻 Synopsis

```bash
bloom doctor [options]
```

---

## 🩺 Diagnostic Checklist Explained

When you run `bloom doctor`, the diagnostic engine performs the following checks in order:

### 1. Dart SDK Check
* **What it checks:** Verifies that `dart` is installed and accessible on `PATH`.
* **Failure Cause:** Dart executable not found on system PATH.
* **Resolution:** Install the Dart SDK or add `<flutter_installation_dir>/bin` to your `PATH`.

### 2. Flutter SDK Check
* **What it checks:** Validates `flutter --version` and engine health.
* **Failure Cause:** Flutter is not installed or git repo is in a detached HEAD state.
* **Resolution:** Download Flutter from [flutter.dev](https://flutter.dev) and run `flutter doctor`.

### 3. Android Toolchain / Java JDK
* **What it checks:** Queries `java -version` and reads `ANDROID_HOME` or `ANDROID_SDK_ROOT`.
* **Failure Cause:** Missing OpenJDK 17 or missing Android SDK command-line tools.
* **Resolution:** Install OpenJDK (`sudo apt install openjdk-17-jdk` or `brew install openjdk@17`) and set `ANDROID_HOME` in your environment.

### 4. iOS / macOS Toolchain (macOS Only)
* **What it checks:** Validates active Xcode Command Line Tools via `xcode-select -p`.
* **Failure Cause:** Xcode not installed or CLI developer directory not set.
* **Resolution:** Run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` and install CocoaPods (`sudo gem install cocoapods`).

### 5. Shorebird OTA CLI Check
* **What it checks:** Queries `shorebird --version` to determine if Over-The-Air code-push deployments are supported on this machine.
* **Notice:** If not installed, reports an `ℹ Optional` notice.
* **Resolution:** Run `curl --proto "=https" --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash`.

### 6. Local Network Interfaces & UDP Discovery Check
* **What it checks:** Inspects available network interfaces (`eth0`, `wlan0`, `en0`) to discover a routable IPv4 address for hosting the Bloom Dev Server and broadcasting UDP beacons to **Bloom Go** clients.
* **Warning:** Flags `⚠ Loopback only (127.0.0.1)` if no active LAN Wi-Fi or Ethernet connection is detected.

### 7. Project-Level Integrity Check (Inside a Bloom Project)
* **`bloom.yaml` validation:** Ensures `bloom.yaml` exists and parses valid YAML.
* **`.env` file:** Validates presence of `.env` configuration file.
* **Route discovery:** Scans `lib/routes/` and lists all discovered filesystem routes with target classes.

---

## 🚪 Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | All required environment and project checks passed successfully. |
| **`1`** | Critical failure in toolchain or project configuration. |
