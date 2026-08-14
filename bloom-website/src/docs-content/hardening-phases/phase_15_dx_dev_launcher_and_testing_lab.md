# Phase 15: Developer Experience, Dev Launcher & Module Sandbox

> **Objective:** Deliver the Bloom Dev Launcher (development builds), team dev server discovery, request replay, state/query visual inspectors, module sandbox (`bloom module dev`), and hardware simulation test harnesses.

---

## 🏗️ Interactive Developer Experience Pipeline

```text
               Bloom Dev Launcher (Mobile App)
                             │
     ┌───────────────────────┼───────────────────────┐
     ▼                       ▼                       ▼
Dev Server Discovery    Team Workstations      Cloud Previews
(LAN UDP Port 5354)    (Chidi / David / CI)   (PR #42 Preview)
     │                       │                       │
     └───────────────────────┼───────────────────────┘
                             ▼
             In-App Interactive Inspection
     (State / Query / Network Replay / Permissions)
```

---

## 📱 1. Bloom Dev Launcher (Development Builds)

The **Bloom Dev Launcher** serves as an interactive development hub installed on physical devices:

* **Switch Servers:** Seamlessly switch between your local laptop, a teammate's workstation, or a remote staging deployment.
* **Server Discovery:** Automatically scans local Wi-Fi networks for active `bloom dev` instances via UDP broadcast.
* **Recent Projects:** Remembers previously visited applications and dev server profiles.

---

## 🔍 2. In-App Visual DevTools & Inspectors

### 1. Network Inspector & Request Replay
* Displays all outgoing HTTP requests, status codes, payload sizes, and response latencies.
* **Request Replay:** Select any failed request and tap **"Replay Request"** to re-execute it with modified parameters.

### 2. State & Signals Inspector
* Visual tree showing all active `Signal` instances, current values, update counts, and active `Watch` widget subscribers.

### 3. Query Cache Inspector
* Real-time list of all `BloomData.query` caches, cache keys, staleness timers, and instant cache purge triggers.

---

## 📦 3. Project Templates & Remote Registry

Scaffold new applications from official or community starter templates:

```bash
# Search available templates
bloom templates

# Create from official template
bloom create my_store --template ecommerce

# Create from remote GitHub repository
bloom create custom_app --template github:bloom-community/chat-template
```

---

## 🧪 4. Bloom Module Sandbox (`bloom module dev`)

For native module authors developing custom Swift/Kotlin plugins:

```bash
cd packages/bloom_camera
bloom module dev
```

1. Boots a minimal, isolated host Flutter application containing **only** the module under development.
2. Provides instant hot reload and native code rebuild loops without needing a large host app.

---

## 🔬 5. Native Module Test Harness (`bloom module test`)

Execute Dart API unit tests, native Android JUnit tests, and native iOS XCTests from a single CLI invocation:

```bash
bloom module test
```

**Output:**
```text
🧪 Executing Bloom Module Test Matrix (bloom_camera)

  • Dart API Unit Tests:     24 / 24 passed (100%)
  • Android JUnit Tests:     12 / 12 passed (100%)
  • iOS XCTest Suite:        14 / 14 passed (100%)

✔ All native module test suites passed successfully!
```

---

## 📶 6. Network & Permission Simulation Harness

Test application edge-cases deterministically in tests or debug builds:

```dart
// Simulate network degradation
BloomDev.simulateNetwork(
  latency: const Duration(seconds: 2),
  failureRate: 0.25, // 25% random HTTP 500s
);

// Simulate device offline state
BloomDev.setOffline(true);

// Simulate permission responses
BloomPermissions.simulate(
  permission: BloomPermission.camera,
  status: BloomPermissionStatus.permanentlyDenied,
);
```

---

## 🧪 Verification & Acceptance Criteria

> See [Spec Conventions & Definition of Done](file:///root/dev/Bloom/docs/hardening-phases/00b_spec_conventions_and_definition_of_done.md). Anti-patterns A1–A6 apply.

### C1. Dev Launcher performs real server discovery
- **When** a `bloom dev` server broadcasts on the LAN.
- **Then** the launcher lists it via UDP discovery (not a hardcoded list).
- **Must not** show a static/hardcoded server list (A1).
- **Test** integration test with a mock UDP broadcast.

### C2. Network Inspector replays real requests
- **When** the user taps "Replay Request" on a captured request.
- **Then** the same request is re-executed with modified params and the new response recorded.
- **Must not** merely re-display the old cached response (A1).
- **Test** widget test asserting the underlying client is re-invoked with new params.

### C3. `bloom module test` executes real native suites
- **When** run in a module with Dart + Android + iOS tests.
- **Then** all three suites run and results are aggregated; non-zero exit if any fail.
- **Must not** print pass counts without invoking the test runners (A1).
- **Test** fixture module → assert exit code reflects real pass/fail.

### C4. `bloom module dev` boots a real sandbox host
- **When** run in a module package.
- **Then** a minimal host app is generated and boots containing only that module, with hot reload.
- **Must not** print "launched" without starting a host process (A1).
- **Test** smoke test asserting the host app is generated and buildable.

### C5. Network/permission simulation affects runtime behavior
- **When** `BloomDev.simulateNetwork(failureRate: 1.0)` is active.
- **Then** 100% of requests fail deterministically.
- **Must not** be a no-op that leaves real networking unchanged (A3).
- **Test** unit test with `failureRate: 1.0` asserts all calls fail.
