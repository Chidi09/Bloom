# bloom_security

Production-hardened security, CORS, security headers, rate limiting, and native WebSocket upgrade utilities for Bloom server applications (`BloomApiRouter` / `BloomMiddleware`).

---

## Features

- **`BloomAdvancedCorsMiddleware`**: Deny-by-default CORS policy. Prevents wildcard origins with credentials, validates preflight methods and headers case-insensitively, rejects disallowed cross-origin requests with 403 Forbidden without emitting allow-origin headers, and provides an explicit opt-in permissive factory.
- **`BloomSecurityHeadersMiddleware`**: Modern HTTP security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Content-Security-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, and conditional `Strict-Transport-Security` over HTTPS).
- **`BloomRateLimitMiddleware`**: Sliding-window rate limiter with trusted proxy validation (`isTrustedProxy`), safe non-spoofable fallback (`anonymous_peer`) for unavailable peer addresses, argument validation, and standard `X-RateLimit-*` / `Retry-After` headers.
- **`BloomRateLimitStore`**: Public storage and evaluation strategy contract with default in-memory sliding-window implementation (`BloomInMemoryRateLimitStore`) and extension points for shared distributed backends.
- **`BloomWebSocketServer` & `BloomWebSocketUpgrade`**: Native `dart:io` WebSocket upgrade routing with deny-by-default cross-origin handshake validation, pre-upgrade admission hooks, active connection caps (`maxConnections`), and inbound frame byte limits (`maxMessageBytes`).

---

## Security Boundaries and Non-Goals

`bloom_security` provides network, transport, and perimeter defenses. To maintain clear separation of concerns, the following areas are outside its scope:

- **Authentication & Identity**: User authentication, session lifecycles, and credential storage are handled by authentication packages such as `bloom_auth_server` or an external identity provider.
- **Cross-Site Request Forgery (CSRF)**: While CORS restrictions and `SameSite` headers protect cross-origin JSON APIs, state-mutating requests with ambient browser credentials (e.g. cookie-based form submissions) require application-level anti-CSRF tokens.
- **Server-Side Request Forgery (SSRF)**: Validating outbound network requests to internal networks or metadata services must be enforced at outbound HTTP client boundaries.
- **Distributed Storage**: The default `BloomInMemoryRateLimitStore` tracks sliding windows in local process memory within the active Dart isolate. For multi-node cluster deployments, implement the `BloomRateLimitStore` interface against your shared data layer.

---

## Installation

Add `bloom_security` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_server: ^0.2.0
  bloom_security: ^0.2.1
```

---

## Usage Examples

### 1. CORS Middleware (`BloomAdvancedCorsMiddleware`)

```dart
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Strict origin allowlist (Deny-by-default for all other origins)
  router.use(BloomAdvancedCorsMiddleware.strict(
    origins: [
      'https://myapp.com',
      'https://admin.myapp.com',
    ],
    allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    allowCredentials: true,
    maxAge: const Duration(hours: 24),
  ));

  // Or for public / open APIs (allowCredentials is false):
  // router.use(BloomAdvancedCorsMiddleware.permissive());

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
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Apply default security headers
  router.use(const BloomSecurityHeadersMiddleware());

  // Or configure a custom Content Security Policy and API profile:
  router.use(BloomSecurityHeadersMiddleware.api(
    contentSecurityPolicy: "default-src 'none'; frame-ancestors 'none'",
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
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  // Configure rate limiter with trusted proxy validation.
  // REQUIRED for anonymous traffic: wire the immediate TCP peer from your
  // server adapter. Without peerAddressExtractor every anonymous client
  // shares one global bucket and a single aggressive client 429s everyone.
  final rateLimiter = BloomRateLimitMiddleware(
    maxRequests: 100,
    window: const Duration(minutes: 1),
    peerAddressExtractor: (req) => req.params['tcp_peer'],
    // Only trust X-Forwarded-For / CF-Connecting-IP from approved reverse proxy IPs
    isTrustedProxy: (peer) => peer == '127.0.0.1' || peer.startsWith('10.0.'),
    // Optional: whitelist internal health checks
    whitelist: {'127.0.0.1'},
  );

  router.use(rateLimiter);

  // Stricter rate limiting on sensitive routes:
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

### 4. Hardened WebSocket Routing (`BloomWebSocketServer` / `serveWithWebSockets`)

Serve both standard HTTP API endpoints and secured WebSocket connections on the same port:

```dart
import 'dart:io';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

void main() async {
  final router = BloomApiRouter();

  router.get('/api/health', (req) {
    return BloomResponse.json({'status': 'healthy'});
  });

  final server = await router.serveWithWebSockets(
    port: 8080,
    allowedOrigins: ['https://myapp.com'],
    maxConnections: 5000,
    maxMessageBytes: 64 * 1024, // 64KB max payload per message frame
    admissionHook: (HttpRequest request) {
      final token = request.headers.value('x-auth-token');
      return token != null && token.isNotEmpty;
    },
    webSocketRoutes: {
      '/ws/chat': (WebSocket socket, HttpRequest request) {
        socket.add('Connected to secure chat');
        socket.listen((data) {
          // Process message safely bounded by maxMessageBytes
        });
      },
    },
  );

  print('Bloom server running at http://${server.address.host}:${server.port}');
}
```
