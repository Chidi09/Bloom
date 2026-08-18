// lib/src/server/bloom_middleware.dart
import 'bloom_request.dart';
import 'bloom_response.dart';

/// Next-handler callback invoked by middleware to pass control to the subsequent middleware or route handler.
typedef BloomNextFunction = Future<BloomResponse> Function();

/// Composable middleware interface for Bloom API routes and full-stack SSR servers.
abstract class BloomMiddleware {
  /// Processes [request] and optionally invokes [next] to continue the pipeline.
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next);
}

/// Function-based middleware implementation.
class FunctionalBloomMiddleware implements BloomMiddleware {
  /// The underlying middleware execution function.
  final Future<BloomResponse?> Function(BloomRequest request, BloomNextFunction next) handler;

  /// Creates a [FunctionalBloomMiddleware] wrapping [handler].
  FunctionalBloomMiddleware(this.handler);

  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) {
    return handler(request, next);
  }
}

/// Built-in CORS middleware for Bloom API endpoints.
class BloomCorsMiddleware implements BloomMiddleware {
  /// The allowed origins header value (e.g. `'*'`).
  final String allowOrigin;

  /// The allowed HTTP methods header value.
  final String allowMethods;

  /// The allowed request headers value.
  final String allowHeaders;

  /// Whether credentials (cookies, auth headers) are permitted in CORS requests.
  final bool allowCredentials;

  /// Creates a [BloomCorsMiddleware] configuration.
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
