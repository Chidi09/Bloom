import 'dart:async';
import 'package:bloom_server/bloom_server.dart';

/// Configurable CORS (Cross-Origin Resource Sharing) middleware for Bloom applications.
///
/// Implements a strict **deny-by-default** policy for cross-origin web requests:
/// - By default, all cross-origin requests are rejected unless explicitly allowed via [allowedOrigins].
/// - Wildcard origins (`'*'`) cannot be combined with [allowCredentials] = `true` (enforced at construction).
/// - Disallowed cross-origin requests and invalid preflight requests are rejected with a 403 Forbidden response
///   and no CORS allow headers are emitted.
/// - Preflight (`OPTIONS`) requests validate requested methods and headers (case-insensitively).
/// - An explicit [BloomAdvancedCorsMiddleware.permissive] factory is available for open public APIs,
///   which emits `Access-Control-Allow-Origin: *` without credential reflection.
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
/// router.use(BloomAdvancedCorsMiddleware.strict(
///   origins: ['https://example.com', 'https://app.example.com'],
///   allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
///   allowCredentials: true,
///   maxAge: const Duration(hours: 1),
/// ));
/// ```
class BloomAdvancedCorsMiddleware implements BloomMiddleware {
  /// Explicit list of allowed origins. Defaults to `const []` (deny by default).
  ///
  /// Specify explicit origins (e.g. `['https://app.example.com']`) or `['*']` for open APIs.
  /// If `['*']` is specified, [allowCredentials] must be `false`.
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
  /// Defaults to `false`. When `true`, [allowedOrigins] must NOT contain `'*'`.
  final bool allowCredentials;

  /// How long the results of an `OPTIONS` preflight request can be cached by the browser.
  ///
  /// Defaults to 24 hours (`Duration(hours: 24)`). Emits `Access-Control-Max-Age`.
  final Duration? maxAge;

  /// Creates a new [BloomAdvancedCorsMiddleware] instance with explicit CORS options.
  ///
  /// - [allowedOrigins]: Explicit origin allowlist (defaults to `const []` for deny-by-default).
  /// - [allowedMethods]: HTTP methods accepted for cross-origin requests.
  /// - [allowedHeaders]: Headers accepted in preflight and actual requests.
  /// - [exposedHeaders]: Response headers exposed to browser scripts via `Access-Control-Expose-Headers`.
  /// - [allowCredentials]: Sets `Access-Control-Allow-Credentials`. Must be `false` if [allowedOrigins] contains `'*'`.
  /// - [maxAge]: Cache duration for `OPTIONS` preflight responses (`Access-Control-Max-Age`).
  ///
  /// Throws [ArgumentError] if [allowedOrigins] contains `'*'` and [allowCredentials] is `true`.
  BloomAdvancedCorsMiddleware({
    this.allowedOrigins = const [],
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
    this.allowCredentials = false,
    this.maxAge = const Duration(hours: 24),
  }) {
    if (allowCredentials && allowedOrigins.contains('*')) {
      throw ArgumentError(
        'Wildcard origin (*) cannot be used when allowCredentials is true '
        '(violates CORS specification and allows arbitrary credential exposure). '
        'Specify explicit origins or set allowCredentials to false.',
      );
    }
  }

  /// Factory for an open/permissive CORS policy (for public APIs and local development).
  ///
  /// Allows all origins (`'*'`) and sets [allowCredentials] to `false`.
  /// Does not reflect arbitrary origins with credentials.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAdvancedCorsMiddleware.permissive());
  /// ```
  factory BloomAdvancedCorsMiddleware.permissive({
    List<String>? allowedMethods,
    List<String>? allowedHeaders,
    List<String>? exposedHeaders,
    Duration? maxAge,
  }) {
    return BloomAdvancedCorsMiddleware(
      allowedOrigins: const ['*'],
      allowCredentials: false,
      allowedMethods: allowedMethods ??
          const [
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'OPTIONS',
            'HEAD',
          ],
      allowedHeaders: allowedHeaders ??
          const [
            'Content-Type',
            'Authorization',
            'X-Requested-With',
            'Accept',
            'Origin',
          ],
      exposedHeaders: exposedHeaders,
      maxAge: maxAge ?? const Duration(hours: 24),
    );
  }

  /// Factory for a secure production policy restricted to specific [origins].
  ///
  /// - [origins]: Explicit list of allowed origin URLs (e.g. `['https://myapp.com']`).
  /// - [allowCredentials]: Whether cross-origin requests may include cookies or credentials (defaults to `false`).
  /// - [maxAge]: Preflight cache duration.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAdvancedCorsMiddleware.strict(
  ///   origins: ['https://dashboard.example.com', 'https://admin.example.com'],
  ///   allowCredentials: true,
  ///   maxAge: const Duration(hours: 2),
  /// ));
  /// ```
  factory BloomAdvancedCorsMiddleware.strict({
    required List<String> origins,
    bool allowCredentials = false,
    Duration? maxAge,
    List<String>? allowedMethods,
    List<String>? allowedHeaders,
    List<String>? exposedHeaders,
  }) {
    return BloomAdvancedCorsMiddleware(
      allowedOrigins: origins,
      allowCredentials: allowCredentials,
      maxAge: maxAge,
      allowedMethods: allowedMethods ??
          const [
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'OPTIONS',
            'HEAD',
          ],
      allowedHeaders: allowedHeaders ??
          const [
            'Content-Type',
            'Authorization',
            'X-Requested-With',
            'Accept',
            'Origin',
          ],
      exposedHeaders: exposedHeaders,
    );
  }

  /// Intercepts the incoming [request] to validate CORS origins, handle preflight `OPTIONS` requests,
  /// or append CORS headers to valid cross-origin responses.
  ///
  /// Disallowed cross-origin requests and invalid preflight requests are rejected with a 403 Forbidden
  /// response without invoking [next], emitting zero allow-origin headers.
  @override
  Future<BloomResponse?> handle(
      BloomRequest request, BloomNextFunction next) async {
    final origin = _extractHeader(request.headers, 'origin');

    // Same-origin or non-browser requests without an Origin header proceed normally.
    if (origin == null || origin.trim().isEmpty) {
      return await next();
    }

    final trimmedOrigin = origin.trim();
    final effectiveOrigin = _resolveEffectiveOrigin(trimmedOrigin);

    // Deny-by-default: if origin is not allowed, reject with 403 without emitting allow-origin headers.
    if (effectiveOrigin == null) {
      return BloomResponse.forbidden(
          'CORS request rejected: origin not allowed');
    }

    final isPreflight = request.method.toUpperCase() == 'OPTIONS';

    // Handle preflight OPTIONS request
    if (isPreflight) {
      final reqMethod = _extractHeader(
        request.headers,
        'access-control-request-method',
      )?.trim().toUpperCase();

      // If preflight specifies a requested method, validate against allowedMethods
      if (reqMethod != null && reqMethod.isNotEmpty) {
        final allowedMethodsUpper =
            allowedMethods.map((m) => m.trim().toUpperCase()).toSet();
        if (!allowedMethodsUpper.contains(reqMethod)) {
          return BloomResponse.forbidden(
            'CORS preflight rejected: method $reqMethod is not allowed',
          );
        }
      }

      // If preflight specifies requested headers, validate each header case-insensitively
      final reqHeadersStr = _extractHeader(
        request.headers,
        'access-control-request-headers',
      );
      if (reqHeadersStr != null && reqHeadersStr.trim().isNotEmpty) {
        final allowedHeadersLower =
            allowedHeaders.map((h) => h.trim().toLowerCase()).toSet();
        final requestedList = reqHeadersStr
            .split(',')
            .map((h) => h.trim())
            .where((h) => h.isNotEmpty);

        for (final reqHeader in requestedList) {
          if (!allowedHeadersLower.contains(reqHeader.toLowerCase())) {
            return BloomResponse.forbidden(
              'CORS preflight rejected: header $reqHeader is not allowed',
            );
          }
        }
      }

      // Preflight is valid: return 204 No Content with configured CORS headers
      final headers = <String, String>{};

      _setHeader(headers, 'Access-Control-Allow-Origin', effectiveOrigin);

      if (allowCredentials) {
        _setHeader(headers, 'Access-Control-Allow-Credentials', 'true');
      }

      final methodsStr = allowedMethods.join(', ');
      _setHeader(headers, 'Access-Control-Allow-Methods', methodsStr);

      final headersStr = allowedHeaders.join(', ');
      _setHeader(headers, 'Access-Control-Allow-Headers', headersStr);

      if (maxAge != null) {
        final maxAgeStr = maxAge!.inSeconds.toString();
        _setHeader(headers, 'Access-Control-Max-Age', maxAgeStr);
      }

      _setHeader(
        headers,
        'Vary',
        'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
      );

      return BloomResponse.noContent(headers: headers);
    }

    // Actual cross-origin request: invoke downstream pipeline and attach CORS headers
    final response = await next();

    _setHeader(
        response.headers, 'Access-Control-Allow-Origin', effectiveOrigin);

    if (allowCredentials) {
      _setHeader(response.headers, 'Access-Control-Allow-Credentials', 'true');
    }

    if (exposedHeaders != null && exposedHeaders!.isNotEmpty) {
      final exposedStr = exposedHeaders!.join(', ');
      _setHeader(response.headers, 'Access-Control-Expose-Headers', exposedStr);
    }

    final currentVary = response.headers['Vary'] ?? response.headers['vary'];
    if (currentVary == null || !currentVary.contains('Origin')) {
      final newVary = currentVary == null ? 'Origin' : '$currentVary, Origin';
      _setHeader(response.headers, 'Vary', newVary);
    }

    return response;
  }

  String? _resolveEffectiveOrigin(String requestOrigin) {
    if (allowedOrigins.contains('*')) {
      if (!allowCredentials) {
        return '*';
      }
      return null;
    }

    final normalizedReqOrigin = requestOrigin.toLowerCase();
    for (final allowed in allowedOrigins) {
      if (allowed.trim().toLowerCase() == normalizedReqOrigin) {
        return requestOrigin;
      }
    }

    return null;
  }

  void _setHeader(Map<String, String> headers, String name, String value) {
    headers[name] = value;
    headers[name.toLowerCase()] = value;
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
