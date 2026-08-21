# `bloom doctor` CLI Reference Manual

Runs a diagnostic audit across your local development environment, verifying required SDKs, native compilers, mobile toolchains, and network interfaces.

---

## 1. Synopsis

```bash
bloom doctor [options]
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-v, --verbose` | Displays detailed environment paths, SDK commit hashes, and diagnostic logs. | `false` |
| `--fix` | Attempts automated remediation for missing symlinks or configuration warnings. | `false` |
| `--help` | Print usage information. | |

---

## 2. Diagnostics Checklist

`bloom doctor` verifies the following toolchains in order:

1. **Dart & Flutter SDK**: Minimum Dart 3.5+ and Flutter 3.24+ versions.
2. **Android Toolchain**: Android SDK Command-Line Tools, `platform-tools` (`adb`), and `JAVA_HOME` (JDK 17+).
3. **iOS Toolchain** (macOS only): Xcode 15+, CocoaPods, and active provisioning profiles.
4. **JS Native & NPM Toolchain**: Bun runtime availability and Node.js fallback.
5. **Shorebird Code Push**: Shorebird CLI authentication and active project link.
6. **Network & Wireless**: Local network IP interfaces for UDP discovery and mobile pairing.

---

## 3. Sample Diagnostic Output

```text
[✓] Bloom Toolchain (v1.0.0, channel stable)
    • Bloom root: /root/dev/Bloom
    • Config manifest: /root/dev/Bloom/bloom.yaml

[✓] Dart & Flutter Toolchain
    • Flutter 3.24.0 • channel stable
    • Dart SDK version: 3.5.0

[✓] Android Toolchain - Develop for Android devices
    • Android SDK at /opt/android-sdk
    • Platform android-34, build-tools 34.0.0
    • Java binary at: /usr/lib/jvm/java-17-openjdk/bin/java

[✓] JS Native & Web Toolchain
    • Bun 1.1.20 detected at /usr/local/bin/bun (Fast ESM vendoring enabled)

[✓] Network & Wireless ADB
    • Local IP interface: 192.168.1.105
    • UDP discovery port: 5354 (Available)

• No issues found. Your Bloom development environment is fully operational!
```
