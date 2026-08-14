# 23. HTTP Networking Client (`BloomHttpClient`)

`BloomHttpClient` is an ergonomic, typed HTTP client wrapper with automatic Base URL resolution, Bearer token injection, request/response interceptors, and strict error handling.

---

## ⚡ Basic Usage

```dart
import 'package:bloom_framework/bloom.dart';

final client = BloomHttpClient(
  baseUrl: 'https://api.bloom.dev/v1',
  timeout: const Duration(seconds: 10),
);

// GET request
final users = await client.get<List<dynamic>>('/users');

// POST request
final newUser = await client.post<Map<String, dynamic>>(
  '/users',
  body: {'name': 'Grace Hopper', 'role': 'Engineer'},
);

// PATCH request
final updated = await client.patch<Map<String, dynamic>>(
  '/users/42',
  body: {'role': 'Lead Engineer'},
);

// DELETE request
await client.delete('/users/42');
```

---

## 🛡️ Strict Base URL Resolution & Error Model

To eliminate subtle misconfiguration bugs during production builds, `BloomHttpClient` **fast-fails** if a relative endpoint is requested when no `baseUrl` is configured:

```dart
final client = BloomHttpClient(); // No baseUrl and no API_BASE_URL env

// THROWS StateError immediately!
await client.get('/users');
```
* **Exception:** `StateError: BloomHttpClient: Cannot resolve relative endpoint "/users" because no baseUrl or API_BASE_URL environment variable was configured.`

---

## 🔑 Dynamic Auth Token Providers

Instead of hardcoding a static token, supply a dynamic `authTokenProvider` callback. Every outgoing HTTP request will resolve the latest active session token (including refreshed tokens):

```dart
final client = BloomHttpClient(
  baseUrl: 'https://api.bloom.dev',
  authTokenProvider: () => inject<BloomAuthBase>().token.value,
);
```

---

## 🪝 Request & Response Interceptors

```dart
// Add Request Interceptor
client.requestInterceptors.add((req) async {
  req.headers['X-App-Version'] = '1.0.0';
  req.headers['X-Device-Id'] = 'device_xyz';
  return req;
});

// Add Response Interceptor
client.responseInterceptors.add((res) async {
  if (res.statusCode == 401) {
    logger.warn('Received 401 Unauthorized. Triggering session refresh...');
    // Optionally invoke auth refresh
  }
  return res;
});
```
