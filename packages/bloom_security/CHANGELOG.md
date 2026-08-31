# 0.2.2 - 2026-08-31

### Security Hardening
- **CORS (`BloomAdvancedCorsMiddleware`)**:
  - Implemented deny-by-default policy (`allowedOrigins` defaults to `const []`).
  - Prohibited wildcard origin (`'*'`) with `allowCredentials = true` at construction time.
  - Rejection of disallowed cross-origin requests and invalid preflight requests with HTTP 403 Forbidden without emitting allow-origin headers.
  - Strict preflight validation for requested methods and case-insensitive headers.
  - Permissive factory explicitly sets `allowCredentials = false` without arbitrary origin reflection.
- **Rate Limiting (`BloomRateLimitMiddleware` & `BloomRateLimitStore`)**:
  - Added `BloomTrustedProxyPredicate` (`isTrustedProxy`) ensuring proxy headers (`CF-Connecting-IP`, `X-Forwarded-For`, `X-Real-IP`, `True-Client-IP`) are never trusted unless the immediate peer is approved.
  - Added safe non-spoofable fallback key (`anonymous_peer`) when peer address is unavailable.
  - Added argument validation for `maxRequests > 0`, `window > Duration.zero`, and `cleanupInterval > Duration.zero`.
  - Introduced public `BloomRateLimitStore` contract and `BloomInMemoryRateLimitStore` for pluggable shared/distributed storage backends.
- **WebSocket Security (`BloomWebSocketServer` & `BloomWebSocketUpgrade`)**:
  - Added configurable origin validation with deny-by-default rejection of cross-origin browser handshakes.
  - Added pre-upgrade `BloomWebSocketAdmissionHook` for authorization and connection filtering.
  - Added active connection cap (`maxConnections`) rejecting over-capacity requests with HTTP 503 Service Unavailable.
  - Added inbound message payload size limit (`maxMessageBytes`) closing over-limit peers with status 1009 (`WebSocketStatus.messageTooBig`).
- **Automated Tests**:
  - Added 27 automated security tests covering CORS denial, preflight headers, spoofed proxy header defense, trusted proxy predicates, WebSocket origin checks, admission hooks, connection caps, and frame size limits.

# 0.2.1 - 2026-08-25

### Fixed
* Bumped `bloom_server` dependency constraint from `^0.1.0` to `^0.2.0` — the stale constraint was incompatible with any sibling package (`bloom_cache`, `bloom_i18n`) requiring `bloom_server ^0.2.0`, breaking `pub get` in any app combining them.

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
