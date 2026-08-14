# 41. Troubleshooting & Frequently Asked Questions (FAQ)

Common issues, failure resolutions, and diagnostic tips.

---

## ❓ Frequently Encountered Issues

### 1. `StateError: BloomHttpClient: Cannot resolve relative endpoint...`
* **Cause:** Your code attempted to call a relative HTTP path (e.g. `http.get('/users')`) but no `baseUrl` was configured in the `BloomHttpClient` constructor and no `API_BASE_URL` was found in `.env`.
* **Fix:** Add `API_BASE_URL=https://api.yourdomain.com` to `.env` or pass `baseUrl: 'https://api.yourdomain.com'` to `BloomHttpClient()`.

---

### 2. `Shorebird CLI is not installed or not available on PATH`
* **Cause:** Running `bloom deploy` (without `--dry-run`) when the `shorebird` executable is missing from your system PATH.
* **Fix:** Install Shorebird:
  ```bash
  curl --proto "=https" --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
  ```
  Then run `shorebird login` to authenticate.

---

### 3. UDP Discovery not finding dev servers in Bloom Go
* **Cause:** Your phone and computer are on different subnets (e.g. phone on cellular data, computer on office LAN) or your Wi-Fi router blocks UDP broadcast packets on port `5354`.
* **Fix:**
  1. Ensure both devices are on the same Wi-Fi SSID.
  2. Use the **"Scan Terminal QR Code"** camera workflow or enter the IP manually (e.g. `http://192.168.1.105:8080`).

---

### 4. `bloom doctor` reports missing JDK or Android SDK
* **Cause:** `ANDROID_HOME` or `JAVA_HOME` environment variables are unset.
* **Fix:** Set the path in your shell profile:
  ```bash
  export ANDROID_HOME=$HOME/Android/Sdk
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin
  ```

---

### 5. `Dependency not found: inject<T>()`
* **Cause:** You attempted to resolve `inject<MyService>()` before it was registered in `AppBootstrapper.onBoot()`.
* **Fix:** Open `lib/app/boot.dart` and register the service:
  ```dart
  container.provideSingleton<MyService>((c) => MyService());
  ```

---

### 6. Native Camera / Notifications work in tests but fail on physical device
* **Cause:** Running in `mode: bare` or forgetting to run `bloom prebuild` to synchronize permissions into `AndroidManifest.xml` and `Info.plist`.
* **Fix:** Run `bloom prebuild` to automatically inject camera permissions and notification channels into native manifests.
