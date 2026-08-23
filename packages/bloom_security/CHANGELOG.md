# 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

# 0.1.0

- Initial release of `bloom_security`.
- Added `BloomCorsMiddleware`: configurable CORS handling with wildcard/origin lists, credential support, headers, and OPTIONS preflight short-circuiting.
- Added `BloomSecurityHeadersMiddleware`: standard HTTP security headers (HSTS on HTTPS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, and Permissions-Policy).
- Added `BloomRateLimitMiddleware`: sliding-window rate limiter with per-IP or custom key extraction, 429 Retry-After handling, rate limit headers, and atomic concurrency safety in Dart isolate.
- Added `BloomWebSocketUpgrade` and `BloomWebSocketServer`: native WebSocket upgrade routing and server binding integrated with `BloomApiRouter`.
