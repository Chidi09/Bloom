// lib/src/server/bloom_middleware.dart
import 'bloom_request.dart';
import 'bloom_response.dart';

/// Next-handler callback invoked by middleware to pass control to the subsequent middleware or route handler in the pipeline.
///
/// Returns the [BloomResponse] produced by downstream handlers.
///
/// ### Example
/// ```dart
/// final response = await next();
/// response.headers['X-Processed-By'] = 'BloomMiddleware';
/// return response;
/// ```
typedef BloomNextFunction = Future<BloomResponse> Function();

/// Composable middleware interface for Bloom API routes, full-stack SSR servers, and gateways.
///
/// Middleware can inspect or modify incoming [BloomRequest] instances, short-circuit
/// execution early (e.g., for authentication failures or CORS preflight), and inspect or
/// modify outgoing [BloomResponse] instances after invoking [next].
///
/// ### Example
/// ```dart
/// class TimingMiddleware implements BloomMiddleware {
///   @override
///   Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
///     final stopwatch = Stopwatch()..start();
///     final response = await next();
///     stopwatch.stop();
///     response.headers['X-Response-Time'] = '${stopwatch.elapsedMilliseconds}ms';
///     return response;
///   }
/// }
///
/// router.use(TimingMiddleware());
/// ```
abstract class BloomMiddleware {
  /// Processes the incoming [request] and optionally invokes [next] to continue the middleware pipeline.
  ///
  /// To pass execution down the chain, await [next] and return its resulting [BloomResponse].
  /// To short-circuit execution (e.g. authentication rejection), return a [BloomResponse] directly
  /// without calling [next].
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next);
}

/// Function-based middleware implementation wrapping a standalone handler callback.
///
/// Allows creating lightweight middleware without defining a new class.
///
/// ### Example
/// ```dart
/// final loggingMiddleware = FunctionalBloomMiddleware((req, next) async {
///   print('--> ${req.method} ${req.path}');
///   final res = await next();
///   print('<-- ${res.statusCode} ${req.path}');
///   return res;
/// });
///
/// router.use(loggingMiddleware);
/// ```
class FunctionalBloomMiddleware implements BloomMiddleware {
  /// The underlying middleware execution callback function.
  final Future<BloomResponse?> Function(BloomRequest request, BloomNextFunction next) handler;

  /// Creates a [FunctionalBloomMiddleware] wrapping the given [handler] callback.
  FunctionalBloomMiddleware(this.handler);

  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) {
    return handler(request, next);
  }
}

/// Built-in Cross-Origin Resource Sharing (CORS) middleware for Bloom API endpoints.
///
/// Handles browser CORS preflight `OPTIONS` requests automatically with HTTP 204 No Content
/// and injects appropriate `Access-Control-*` headers into all outgoing responses.
///
/// ### Example
/// ```dart
/// // Default permissive CORS (all origins allowed)
/// router.use(BloomCorsMiddleware());
///
/// // Custom restricted CORS configuration
/// router.use(BloomCorsMiddleware(
///   allowOrigin: 'https://app.example.com',
///   allowMethods: 'GET, POST, PUT, DELETE',
///   allowHeaders: 'Content-Type, Authorization, X-Workspace-ID',
///   allowCredentials: true,
/// ));
/// ```
class BloomCorsMiddleware implements BloomMiddleware {
  /// The `Access-Control-Allow-Origin` header value (e.g. `'*'` or `'https://example.com'`).
  final String allowOrigin;

  /// The `Access-Control-Allow-Methods` header value.
  final String allowMethods;

  /// The `Access-Control-Allow-Headers` header value.
  final String allowHeaders;

  /// Whether credentials (cookies, HTTP authorization headers, TLS client certs) are permitted.
  final bool allowCredentials;

  /// Creates a [BloomCorsMiddleware] with customizable CORS headers.
  const BloomCorsMiddleware({
    this.allowOrigin = '*',
    this.allowMethods = 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    this.allowHeaders = 'Content-Type, Authorization, X-Requested-With',
    this.allowCredentials = true,
  });

  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    if (request.method == 'OPTIONS') {
      return BloomResponse.noContent(headers: {
        'access-control-allow-origin': allowOrigin,
        'access-control-allow-methods': allowMethods,
        'access-control-allow-headers': allowHeaders,
        if (allowCredentials) 'access-control-allow-credentials': 'true',
      });
    }

    final response = await next();
    response.headers['access-control-allow-origin'] = allowOrigin;
    if (allowCredentials) {
      response.headers['access-control-allow-credentials'] = 'true';
    }
    return response;
  }
}

