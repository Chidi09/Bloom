# 1. Installation & Environment Setup

Welcome to **Bloom**. This guide walks you through system prerequisites, installing the Bloom CLI, configuring your environment variables, and verifying your installation.

---

## 📋 Prerequisites

Bloom requires the official Flutter and Dart toolchains installed on your system.

| Toolchain | Minimum Supported Version | Recommended Version |
| :--- | :--- | :--- |
| **Dart SDK** | `>= 3.5.0` | `3.6.0+` |
| **Flutter SDK** | `>= 3.24.0` | `3.27.0+` |
| **Java JDK** (Android) | JDK 17 (Eclipse Temurin / OpenJDK) | JDK 17 / 21 |
| **Android Studio / Command-Line Tools** | SDK Platform 34+, Build-Tools 34.0.0+ | Latest |
| **Xcode** (macOS / iOS only) | Xcode 15.0+ | Xcode 16.0+ |
| **CocoaPods** (macOS / iOS only) | 1.14.0+ | 1.15.0+ |

---

## 📦 Installing the Bloom CLI

The Bloom Command-Line Interface (`bloom`) is published as a global Dart executable.

### Global Installation via Pub
```bash
dart pub global activate bloom_cli
```

### Local Workspace Development Installation (Monorepo)
If you are developing inside the Bloom monorepo or using a local checkout:
```bash
dart pub global activate --source path /root/dev/Bloom/packages/bloom_cli
```

---

## 🌐 Configuring System PATH

Ensure that Dart's global pub cache binary directory is added to your shell configuration (`~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`):

### Linux / macOS
```bash
# Add Dart global bin to PATH
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Linux (root environment)
```bash
export PATH="$PATH":"/root/.pub-cache/bin"
```

### Windows (PowerShell)
```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\Pub\Cache\bin", "User")
```

Reload your active shell session:
```bash
source ~/.bashrc # or source ~/.zshrc
```

---

## 🩺 Verifying Toolchain Health (`bloom doctor`)

Once installed, run `bloom doctor` to validate your SDK versions, platform toolchains, and environment configuration:

```bash
bloom doctor
```

### Expected Output
```text
🩺 Bloom Diagnostic System Health Check

  Checking Dart SDK... ✔ OK (Dart SDK version: 3.6.0 (stable))
  Checking Flutter SDK... ✔ OK (Flutter 3.27.0 • channel stable)
  Checking Android Toolchain / Java... ✔ OK (SDK: /opt/android-sdk)
  Checking Shorebird CLI (OTA)... ℹ Optional (run curl -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash)
  Checking Local Network Interfaces... ✔ OK (LAN IP: 192.168.1.105)

Environment is healthy and ready for Bloom development!
```

---

## 🔄 Updating Bloom CLI

To update to the latest published version of the Bloom CLI:
```bash
dart pub global activate bloom_cli
```

To verify the installed CLI version:
```bash
bloom --version
```
*(Outputs: `Bloom CLI v0.1.0`)*
