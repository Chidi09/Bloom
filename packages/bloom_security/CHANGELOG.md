# 0.1.0

- Initial release of `bloom_security`.
- Added `BloomCorsMiddleware`: configurable CORS handling with wildcard/origin lists, credential support, headers, and OPTIONS preflight short-circuiting.
- Added `BloomSecurityHeadersMiddleware`: standard HTTP security headers (HSTS on HTTPS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, and Permissions-Policy).
- Added `BloomRateLimitMiddleware`: sliding-window rate limiter with per-IP or custom key extraction, 429 Retry-After handling, rate limit headers, and atomic concurrency safety in Dart isolate.
- Added `BloomWebSocketUpgrade` and `BloomWebSocketServer`: native WebSocket upgrade routing and server binding integrated with `BloomApiRouter`.
