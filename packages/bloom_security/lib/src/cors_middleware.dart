import 'dart:async';
import 'package:bloom_server/bloom_server.dart';

/// Configurable CORS (Cross-Origin Resource Sharing) middleware for Bloom applications.
///
/// Features:
/// - Support for wildcard (`'*'`) or explicit origin lists.
/// - Dynamic request `Origin` header resolution for credentialed requests (`Access-Control-Allow-Credentials: true`).
/// - Automatic handling and short-circuiting of `OPTIONS` preflight requests.
/// - Configurable allowed methods, headers, exposed headers, and preflight max age.
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
/// router.use(BloomAdvancedCorsMiddleware(
///   allowedOrigins: ['https://example.com', 'https://app.example.com'],
///   allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
///   allowCredentials: true,
///   maxAge: const Duration(hours: 1),
/// ));
/// ```
class BloomAdvancedCorsMiddleware implements BloomMiddleware {
  /// Origins allowed to access the resource. Defaults to `['*']`.
  ///
  /// When set to `['*']` and [allowCredentials] is `true`, the requesting origin
  /// is dynamically reflected in `Access-Control-Allow-Origin` to comply with CORS specifications.
  final List<String> allowedOrigins;

  /// HTTP methods permitted when accessing the resource.
  ///
  /// Defaults to `['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD']`.
  final List<String> allowedMethods;

  /// HTTP headers permitted in the request.
  ///
  /// Defaults to `['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin']`.
  final List<String> allowedHeaders;

  /// HTTP headers exposed to browser JavaScript via `Access-Control-Expose-Headers`.
  ///
  /// When `null` or empty, no expose headers are emitted.
  final List<String>? exposedHeaders;

  /// Whether the request can include credentials (cookies, authorization headers, TLS client certs).
  ///
  /// Defaults to `true`. Emits `Access-Control-Allow-Credentials: true`.
  final bool allowCredentials;

  /// How long the results of an `OPTIONS` preflight request can be cached by the browser.
  ///
  /// Defaults to 24 hours (`Duration(hours: 24)`). Emits `Access-Control-Max-Age`.
  final Duration? maxAge;

  /// Creates a new [BloomAdvancedCorsMiddleware] instance with explicit CORS options.
  ///
  /// - [allowedOrigins]: Origin whitelist or `['*']` for wildcard.
  /// - [allowedMethods]: HTTP methods accepted for cross-origin requests.
  /// - [allowedHeaders]: Headers accepted in preflight and actual requests.
  /// - [exposedHeaders]: Response headers exposed to browser scripts via `Access-Control-Expose-Headers`.
  /// - [allowCredentials]: Sets `Access-Control-Allow-Credentials`. When `true` and [allowedOrigins] includes `'*'`,
  ///   the requesting origin is dynamically reflected to adhere to the CORS specification.
  /// - [maxAge]: Cache duration for `OPTIONS` preflight responses (`Access-Control-Max-Age`).
  ///
  /// Example:
  /// ```dart
  /// final cors = BloomAdvancedCorsMiddleware(
  ///   allowedOrigins: ['https://example.com'],
  ///   allowedMethods: ['GET', 'POST'],
  ///   maxAge: const Duration(hours: 12),
  /// );
  /// ```
  const BloomAdvancedCorsMiddleware({
    this.allowedOrigins = const ['*'],
    this.allowedMethods = const [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
      'HEAD',
    ],
    this.allowedHeaders = const [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
      'Accept',
      'Origin',
    ],
    this.exposedHeaders,
    this.allowCredentials = true,
    this.maxAge = const Duration(hours: 24),
  });

  /// Factory for a permissive CORS policy (development/open APIs).
  ///
  /// Allows all origins (`'*'`) and credentials.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAdvancedCorsMiddleware.permissive());
  /// ```
  factory BloomAdvancedCorsMiddleware.permissive() {
    return const BloomAdvancedCorsMiddleware(
      allowedOrigins: ['*'],
      allowCredentials: true,
    );
  }

  /// Factory for a secure production policy restricted to specific [origins].
  ///
  /// - [origins]: Explicit list of allowed origin URLs (e.g. `['https://myapp.com']`).
  /// - [allowCredentials]: Whether cross-origin requests may include cookies or credentials (defaults to `true`).
  /// - [maxAge]: Preflight cache duration.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAdvancedCorsMiddleware.strict(
  ///   origins: ['https://dashboard.example.com', 'https://admin.example.com'],
  ///   maxAge: const Duration(hours: 2),
  /// ));
  /// ```
  factory BloomAdvancedCorsMiddleware.strict({
    required List<String> origins,
    bool allowCredentials = true,
    Duration? maxAge,
  }) {
    return BloomAdvancedCorsMiddleware(
      allowedOrigins: origins,
      allowCredentials: allowCredentials,
      maxAge: maxAge,
    );
  }

  /// Intercepts the incoming [request] to handle CORS preflight `OPTIONS` requests or append CORS headers.
  ///
  /// For `OPTIONS` preflight requests, immediately returns a 204 No Content response with
  /// `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`,
  /// and `Access-Control-Max-Age` headers without invoking [next].
  ///
  /// For all other requests, calls [next] and appends `Access-Control-Allow-Origin`,
  /// `Access-Control-Allow-Credentials`, `Access-Control-Expose-Headers`, and `Vary: Origin` to the response.
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final origin = _extractHeader(request.headers, 'origin');
    final isPreflight = request.method.toUpperCase() == 'OPTIONS';

    final effectiveOrigin = _resolveEffectiveOrigin(origin);

    // Preflight (OPTIONS) requests are fully handled here and must not reach downstream route handlers.
    if (isPreflight) {
      final headers = <String, String>{};

      if (effectiveOrigin != null) {
        headers['Access-Control-Allow-Origin'] = effectiveOrigin;
        headers['access-control-allow-origin'] = effectiveOrigin;
      }

      if (allowCredentials) {
        headers['Access-Control-Allow-Credentials'] = 'true';
        headers['access-control-allow-credentials'] = 'true';
      }

      final methodsStr = allowedMethods.join(', ');
      headers['Access-Control-Allow-Methods'] = methodsStr;
      headers['access-control-allow-methods'] = methodsStr;

      // Echo requested headers if present, else fallback to allowedHeaders list
      final reqHeaders = _extractHeader(request.headers, 'access-control-request-headers');
      final headersStr = (reqHeaders != null && reqHeaders.isNotEmpty)
          ? reqHeaders
          : allowedHeaders.join(', ');
      headers['Access-Control-Allow-Headers'] = headersStr;
      headers['access-control-allow-headers'] = headersStr;

      if (maxAge != null) {
        final maxAgeStr = maxAge!.inSeconds.toString();
        headers['Access-Control-Max-Age'] = maxAgeStr;
        headers['access-control-max-age'] = maxAgeStr;
      }

      headers['Vary'] = 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers';

      return BloomResponse.noContent(headers: headers);
    }

    // Process downstream handler/middleware
    final response = await next();

    // Attach CORS headers to response
    if (effectiveOrigin != null) {
      response.headers['Access-Control-Allow-Origin'] = effectiveOrigin;
      response.headers['access-control-allow-origin'] = effectiveOrigin;
    }

    if (allowCredentials) {
      response.headers['Access-Control-Allow-Credentials'] = 'true';
      response.headers['access-control-allow-credentials'] = 'true';
    }

    if (exposedHeaders != null && exposedHeaders!.isNotEmpty) {
      final exposedStr = exposedHeaders!.join(', ');
      response.headers['Access-Control-Expose-Headers'] = exposedStr;
      response.headers['access-control-expose-headers'] = exposedStr;
    }

    final currentVary = response.headers['Vary'] ?? response.headers['vary'];
    if (currentVary == null || !currentVary.contains('Origin')) {
      final newVary = currentVary == null ? 'Origin' : '$currentVary, Origin';
      response.headers['Vary'] = newVary;
      response.headers['vary'] = newVary;
    }

    return response;
  }

  String? _resolveEffectiveOrigin(String? requestOrigin) {
    if (allowedOrigins.contains('*')) {
      // If credentials are allowed, CORS specification forbids '*' as Access-Control-Allow-Origin.
      // In that case, we reflect the requesting origin if present.
      if (allowCredentials && requestOrigin != null && requestOrigin.isNotEmpty) {
        return requestOrigin;
      }
      return '*';
    }

    if (requestOrigin != null && requestOrigin.isNotEmpty) {
      final normalizedReqOrigin = requestOrigin.trim().toLowerCase();
      for (final allowed in allowedOrigins) {
        if (allowed.trim().toLowerCase() == normalizedReqOrigin) {
          return requestOrigin;
        }
      }
    }

    // If allowedOrigins does not include wildcard and request origin is not in the allowed list,
    // we return the first allowed origin or null.
    return allowedOrigins.isNotEmpty ? allowedOrigins.first : null;
  }

  String? _extractHeader(Map<String, String> headers, String headerName) {
    final lowerName = headerName.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }
}
