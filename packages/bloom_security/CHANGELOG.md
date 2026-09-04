# Unreleased

### Security
* **WS Host-header fallback gated behind opt-in (#27)**: the same-origin check's reverse-proxy fallback (comparing `Origin` to the client-supplied `Host` header) is now off by default (`allowProxyHostFallback: false`); enable only when a trusted proxy restores the original Host.
* **Shared anonymous bucket warning (#24)**: the default key extractor prints a loud one-time warning when all anonymous clients share the `anonymous_peer` bucket; middleware/library/README docs now show `peerAddressExtractor` wiring from the server adapter.

### Fixed
* **WS subprotocol negotiation (#27)**: `BloomWebSocketServer` now accepts a `protocols` list. When a client offers subprotocols and none match, the handshake is rejected with 400 instead of upgrading — dart:io cannot omit the `Sec-WebSocket-Protocol` header once the client offers protocols, so echoing nothing requires declining the upgrade.
* **WS route patterns escape literal segments (#27)**: static characters in registered path patterns (e.g. `.`) are regex-escaped so `/ws/v1.2/endpoint` no longer matches `/ws/v1x2/endpoint`.
* **WS idle keepalive (#27)**: new configurable `pingInterval` sets `WebSocket.pingInterval` on upgraded sockets so half-open connections are detected and closed instead of pinning `maxConnections` capacity. Validated to be positive when provided.
* **Dual-case header writes (#27)**: the CORS, rate-limit, and security-headers middlewares now write each header in a single canonical case instead of both `X-...` and `x-...` variants.

### Documentation
* **Security docs lead with `.strict()` (#27)**: the package-level example now starts from the strict CORS policy instead of `.permissive()`.

### Fixed
* **Window-aware stale-bucket prune (#25)**: `BloomInMemoryRateLimitStore` retains entries for the longest enforced window (min 60s) instead of a hardcoded 10-minute cutoff, so hour-long windows stay enforced. Added a `debugPrune` testing hook; failed middleware construction now disposes its owned store instead of leaking a timer.
* **Suite migrated to `package:test` (#26)**: removed the hand-rolled runner (`test_helpers`/`all_tests`); `dart test` now discovers the full suite (30 tests) and exits 0.

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
