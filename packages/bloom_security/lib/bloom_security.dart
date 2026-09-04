/// First-party security, CORS, security headers, rate limiting, and native WebSocket upgrade utilities for Bloom servers.
///
/// Provides configurable Cross-Origin Resource Sharing ([BloomAdvancedCorsMiddleware]), industry-standard
/// security headers ([BloomSecurityHeadersMiddleware]), concurrency-safe sliding-window rate limiting
/// ([BloomRateLimitMiddleware]), and dual HTTP / WebSocket upgrade routing ([BloomWebSocketServer]).
///
/// ### Example
/// ```dart
/// import 'package:bloom_server/bloom_server.dart';
/// import 'package:bloom_security/bloom_security.dart';
///
/// void main() async {
///   final router = BloomApiRouter();
///
///   // Enable CORS and standard security headers
///   router.use(BloomAdvancedCorsMiddleware.strict(
///     origins: ['https://app.example.com'],
///   ));
///   router.use(const BloomSecurityHeadersMiddleware());
///
///   // Apply rate limiting (e.g. 100 requests per minute by client IP).
///   // Wire peerAddressExtractor from the server adapter: without it all
///   // anonymous clients share one global bucket.
///   router.use(BloomRateLimitMiddleware(
///     maxRequests: 100,
///     window: const Duration(minutes: 1),
///     peerAddressExtractor: (req) => req.params['tcp_peer'],
///   ));
///
///   router.get('/api/health', (req) => BloomResponse.json({'status': 'ok'}));
///   await router.serve(port: 8080);
/// }
/// ```
library;

export 'src/cors_middleware.dart';
export 'src/rate_limit_middleware.dart';
export 'src/security_headers_middleware.dart';
export 'src/websocket_upgrade.dart';
