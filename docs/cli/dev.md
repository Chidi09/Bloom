# `bloom dev` CLI Reference Manual

Launches the interactive Bloom Developer Experience (DX) server with live filesystem watching, automatic route regeneration (`routes.g.dart`), terminal TUI, and QR wireless pairing.

---

## 1. Synopsis

```bash
bloom dev [options]
```

---

## 2. Options & Flags

| Flag | Abbreviation | Default | Description |
| :--- | :--- | :--- | :--- |
| `--device` | `-d` | Auto-detect | Target device ID or emulator name (e.g. `chrome`, `macos`, `emulator-5554`). |
| `--flavor` | `-f` | `null` | Active build flavor to run (e.g. `development`, `staging`, `production`). Injects `BLOOM_FLAVOR` dart-define. |
| `--port` | `-p` | `8080` | Local HTTP port for the Bloom Dev Server manifest, QR hosting, and remote DevTools endpoints. |
| `--wireless` | `-w` | `false` | Enable wireless mobile pairing. Automatically broadcasts local network UDP discovery beacons and prints ASCII QR code. |
| `--discovery` | | `true` | Broadcast local network UDP beacons on port `5354` for instant auto-discovery by the **Bloom Go** mobile app. |
| `--help` | `-h` | | Print usage information. |

---

## 3. Interactive Terminal Keyboard Controls

While `bloom dev` is running, the terminal accepts instant single-key interactive shortcuts:

| Key | Action | Description |
| :---: | :--- | :--- |
| <kbd>r</kbd> | **Hot Reload** | Hot reloads UI changes across all connected Flutter and Bloom Go clients. |
| <kbd>R</kbd> | **Hot Restart** | Reinitializes app state, re-runs `Bloom.boot()`, and resets all Signals. |
| <kbd>w</kbd> | **Toggle QR Code** | Toggles the terminal ASCII QR code for connecting mobile devices. |
| <kbd>d</kbd> | **Print Devices** | Lists all available physical devices, emulators, and wireless connections. |
| <kbd>o</kbd> / <kbd>v</kbd> | **Open DevTools** | Opens Flutter DevTools inspection console in default browser. |
| <kbd>c</kbd> | **Clear Console** | Clears the terminal screen and reprints the active session banner. |
| <kbd>q</kbd> | **Quit Session** | Stops the dev server, halts background watchers, and exits cleanly. |

---

## 4. Exit Codes

| Code | Meaning |
| :---: | :--- |
| **`0`** | Clean session termination triggered by developer (<kbd>q</kbd> or `SIGINT`). |
| **`1`** | Fatal error: Port collision, missing Flutter binary, or critical startup exception. |
