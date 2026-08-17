# bloom_security

First-party security, CORS, security headers, rate limiting, and native WebSocket upgrade utilities for Bloom server applications (`BloomApiRouter` / `BloomMiddleware`).

---

## Features

- **`BloomAdvancedCorsMiddleware`**: Configurable CORS middleware with origin list/wildcard support, credentials handling, and automatic `OPTIONS` preflight short-circuiting. `bloom_framework` itself ships a much simpler `BloomCorsMiddleware` (single origin string, no allowlist/exposed-headers/max-age) for basic cases — reach for `BloomAdvancedCorsMiddleware` here when you need a real per-origin allowlist, exposed headers, preflight caching, or spec-correct credentialed-origin reflection.
- **`BloomSecurityHeadersMiddleware`**: Modern HTTP security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Content-Security-Policy`, and conditional `Strict-Transport-Security` over HTTPS).
- **`BloomRateLimitMiddleware`**: In-memory sliding-window rate limiter with client IP / custom key extraction, burst protection, concurrency safety in Dart isolates, and standard `X-RateLimit-*` / `Retry-After` headers.
- **`BloomWebSocketServer` & `BloomWebSocketUpgrade`**: Native `dart:io` WebSocket upgrade routing alongside `BloomApiRouter` routes.

---

## Installation

Add `bloom_security` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_framework:
    path: ../bloom_framework
  bloom_security:
    path: ../bloom_security
```

---

## Usage Examples

### 1. CORS Middleware (`BloomAdvancedCorsMiddleware`)

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Option A: Permissive CORS for development / public APIs
  router.use(BloomAdvancedCorsMiddleware.permissive());

  // Option B: Strict origin whitelist with credentials and custom headers
  router.use(BloomAdvancedCorsMiddleware(
    allowedOrigins: [
      'https://myapp.com',
      'https://admin.myapp.com',
    ],
    allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    allowCredentials: true,
    maxAge: Duration(hours: 24),
  ));

  router.get('/api/users', (req) {
    return BloomResponse.json([
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'},
    ]);
  });

  await router.serve(port: 8080);
}
```

---

### 2. Security Headers Middleware (`BloomSecurityHeadersMiddleware`)

Automatically sets `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, and `Strict-Transport-Security` (only when HTTPS is detected).

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Apply default security headers
  router.use(const BloomSecurityHeadersMiddleware());

  // Or configure a custom Content Security Policy and API profile:
  router.use(BloomSecurityHeadersMiddleware.api(
    contentSecurityPolicy: "default-src 'self'; script-src 'self'",
  ));

  router.get('/api/status', (req) {
    return BloomResponse.json({'status': 'ok'});
  });

  await router.serve(port: 8080);
}
```

---

### 3. Rate Limiting Middleware (`BloomRateLimitMiddleware`)

Sliding-window rate limiter preventing brute force and traffic spikes. Returns `429 Too Many Requests` with a `Retry-After` header when exceeded.

```dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Limit clients to 100 requests per minute by IP address
  final rateLimiter = BloomRateLimitMiddleware(
    maxRequests: 100,
    window: const Duration(minutes: 1),
    // Optional: whitelist internal health checks / trusted IPs
    whitelist: {'127.0.0.1'},
  );

  router.use(rateLimiter);

  // You can also apply stricter rate limiting to sensitive routes:
  final strictAuthLimiter = BloomRateLimitMiddleware(
    maxRequests: 5,
    window: const Duration(minutes: 15),
  );

  router.post('/api/auth/reset-password', (req) {
    return BloomResponse.json({'message': 'Password reset link sent'});
  }, middlewares: [strictAuthLimiter]);

  await router.serve(port: 8080);
}
```

---

### 4. WebSocket Upgrade & Echo Server (`BloomWebSocketServer` / `serveWithWebSockets`)

Seamlessly serve both standard HTTP API endpoints and real-time WebSocket connections on the same port:

```dart
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Standard Bloom HTTP routes
  router.get('/api/health', (req) {
    return BloomResponse.json({'status': 'healthy'});
  });

  // Start server with WebSocket routes registered
  final server = await router.serveWithWebSockets(
    port: 8080,
    webSocketRoutes: {
      // Minimal WebSocket Echo Server
      '/ws/echo': (WebSocket socket, HttpRequest request) {
        print('Client connected to /ws/echo from ${request.connectionInfo?.remoteAddress}');

        socket.listen(
          (message) {
            print('Received: $message');
            socket.add('Echo: $message');
          },
          onDone: () => print('Client disconnected'),
          onError: (err) => print('WebSocket error: $err'),
        );
      },

      // Chat Room WebSocket
      '/ws/chat': (WebSocket socket, HttpRequest request) {
        socket.add('Welcome to Bloom Realtime Chat!');
        socket.listen((data) {
          // Handle chat message
        });
      },
    },
  );

  print('Bloom server running at http://${server.address.host}:${server.port}');
}
```
