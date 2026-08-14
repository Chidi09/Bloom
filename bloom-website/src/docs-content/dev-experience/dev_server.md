# 32. Bloom Dev Server & HTTP Endpoints

When `bloom dev` runs, it starts an embedded HTTP daemon (default port `8080`) providing live telemetry, project manifests, QR payloads, and device pairing endpoints.

---

## 🌐 Embedded API Endpoints

### 1. `GET /manifest.json`
Returns project metadata, platform SDK targets, build flavors, and discovered filesystem routes.
* **Response `200 OK`:**
  ```json
  {
    "name": "bloom_shop",
    "version": "1.0.0",
    "flavor": "development",
    "routes": [
      {"path": "/", "component": "IndexRoute"},
      {"path": "/products/:id", "component": "ProductsIdRoute"}
    ],
    "platforms": {
      "androidMinSdk": 24,
      "iosMinVersion": "15.0"
    }
  }
  ```

### 2. `GET /health`
Returns dev server uptime, active hot reload count, hot restart count, and connected device count.
* **Response `200 OK`:**
  ```json
  {
    "status": "healthy",
    "hotReloads": 12,
    "hotRestarts": 2,
    "connectedDevices": 2,
    "uptimeSeconds": 480
  }
  ```

### 3. `GET /qr`
Returns the terminal QR code payload in JSON or raw ANSI text format:
* Query param: `?format=ansi` returns raw terminal block characters.
* Response contains `payload` URL (e.g. `http://192.168.1.105:8080`).

### 4. `POST /devices/pair`
Invoked by **Bloom Go** to register a physical mobile client session with the workstation:
* **Request Body:**
  ```json
  {
    "deviceId": "pixel_8_pro_001",
    "deviceName": "Google Pixel 8 Pro",
    "platform": "android",
    "osVersion": "Android 14"
  }
  ```
* **Response `200 OK`:**
  ```json
  {
    "status": "paired",
    "sessionId": "session_abc123"
  }
  ```

---

## 🔒 CORS & Network Binding

* **CORS Headers:** All dev server endpoints emit `Access-Control-Allow-Origin: *` to allow local web browsers and Bloom Go clients to query metadata without cross-origin blocks.
* **Network Binding:** Binds to `InternetAddress.anyIPv4` (`0.0.0.0`), allowing both local loopback (`127.0.0.1`) and local area network (LAN) connections from mobile devices on the same Wi-Fi router.
