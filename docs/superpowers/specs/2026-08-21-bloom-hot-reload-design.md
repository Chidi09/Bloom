# Unified Bloom Hot Reload & Live Sync Specification

**Document Version:** 1.0.0  
**Date:** 2026-08-21  
**Status:** Approved  
**Author:** Bloom Architecture & Antigravity  

---

## 1. Overview & Objective

Provide a zero-configuration, sub-second Hot Reload and Live Sync pipeline across the full Bloom stack:
1. **Frontend (Bloom JS Native Web)**: Real-time browser live reload over Server-Sent Events (SSE), fast incremental compilation (`dart compile js -O0`), and automatic dev client injection.
2. **Backend (Bloom Server / SSR)**: Supervised sub-isolate lifecycle management with `< 80ms` server restart times on controller or route changes without dropping database connection pools.

---

## 2. Architecture & Components

```
                      ┌────────────────────────────────────────┐
                      │          bloom dev / bloom js dev      │
                      └───────────────────┬────────────────────┘
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
   ┌─────────────────────────────┐                 ┌─────────────────────────────┐
   │    Bloom JS Web Dev Engine  │                 │   Bloom Server Supervisor   │
   │                             │                 │                             │
   │  • FileWatcher (lib/, web/) │                 │  • Master Socket Holder     │
   │  • Fast `-O0` Dart Compiler │                 │  • Child Worker Isolate     │
   │  • SSE Broadcast (/_bloom_hr│                 │  • Source Watcher           │
   │  • HTML Client Auto-Injector│                 │  • <80ms Isolate Re-spawner │
   └──────────────┬──────────────┘                 └──────────────┬──────────────┘
                  │ SSE Event                                     │ Port Hand-off
                  ▼                                               ▼
   ┌─────────────────────────────┐                 ┌─────────────────────────────┐
   │     Browser DOM Client      │                 │     Multi-Isolate Server    │
   │  • Receives 'reload' event  │                 │  • Active DB Connection     │
   │  • Triggers instant refresh │                 │  • Hot REST & WS Endpoints  │
   └─────────────────────────────┘                 └─────────────────────────────┘
```

### Key Modules in `packages/bloom_cli/lib/src/dev/`

* **`BloomLiveReloadServer`** (`live_reload_server.dart`):
  * Binds dev HTTP server with accurate MIME types and SPA fallback.
  * Manages SSE client connections at `/_bloom_hr`.
  * Dynamically injects the zero-dependency live reload client script into `index.html`.
* **`BloomSourceWatcher`** (`source_watcher.dart`):
  * Debounced (150ms) recursive file monitor for `lib/`, `web/`, and `apps/`.
  * Filters out `.git`, `.dart_tool`, `build/`, and temp files.
* **`BloomServerSupervisor`** (`server_supervisor.dart`):
  * Supervises server backend processes using `Isolate.spawnUri` or sub-process watcher.

---

## 3. Communication Protocol (SSE `/_bloom_hr`)

### Headers:
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
Access-Control-Allow-Origin: *
```

### Event Payloads:
* **Reload Signal**:
  ```text
  event: reload
  data: {"timestamp": 1787322900000, "reason": "header.dart"}
  ```
* **Build Error Signal**:
  ```text
  event: error
  data: {"message": "Error: Undefined name 'TaskStatus' at line 42."}
  ```

---

## 4. Client Script (Auto-Injected)

```html
<script>
  (() => {
    if (window.__BLOOM_HR_ACTIVE__) return;
    window.__BLOOM_HR_ACTIVE__ = true;
    const connect = () => {
      const es = new EventSource('/_bloom_hr');
      es.addEventListener('reload', () => {
        console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
        window.location.reload();
      });
      es.addEventListener('error', (e) => {
        if (e.data) {
          console.error('[Bloom Build Error]', e.data);
        }
      });
      es.onerror = () => {
        es.close();
        setTimeout(connect, 1000);
      };
    };
    connect();
  })();
</script>
```

---

## 5. Testing & Quality Gates

* **Unit Tests**:
  * `test/dev/live_reload_server_test.dart`
  * `test/dev/source_watcher_test.dart`
* **Analyzer Gate**:
  * `dart analyze` passes with 0 errors and 0 warnings across `packages/bloom_cli`.
