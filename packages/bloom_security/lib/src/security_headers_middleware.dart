import 'dart:async';
import 'package:bloom_server/bloom_server.dart';

/// Middleware setting industry-standard HTTP security headers.
///
/// Configurable headers include:
/// - `X-Content-Type-Options`: defaults to `nosniff`.
/// - `X-Frame-Options`: defaults to `DENY`.
/// - `Referrer-Policy`: defaults to `strict-origin-when-cross-origin`.
/// - `Strict-Transport-Security` (HSTS): automatically emitted only when the incoming request is HTTPS
///   (or forwarded via HTTPS) to prevent breaking local HTTP development environments.
/// - `Content-Security-Policy`: conservative default policy provided, fully overridable or disableable.
/// - `Cross-Origin-Opener-Policy` & `Cross-Origin-Resource-Policy`: defaults to `same-origin`.
/// - `Permissions-Policy`: optional hardware/feature permissions policy.
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
/// router.use(const BloomSecurityHeadersMiddleware());
/// ```
class BloomSecurityHeadersMiddleware implements BloomMiddleware {
  /// Default Content Security Policy directive string.
  ///
  /// Sets `default-src 'self'`, restricts object/script sources, and allows self-hosted and HTTPS images.
  static const String defaultCsp =
      "default-src 'self'; "
      "img-src 'self' data: https:; "
      "script-src 'self'; "
      "style-src 'self' 'unsafe-inline'; "
      "object-src 'none'; "
      "base-uri 'self'; "
      "connect-src 'self'";

  /// Value for `X-Content-Type-Options`. Set to `null` to omit. Defaults to `'nosniff'`.
  final String? contentTypeOptions;

  /// Value for `X-Frame-Options`. Set to `null` to omit. Defaults to `'DENY'`.
  final String? frameOptions;

  /// Value for `Referrer-Policy`. Set to `null` to omit. Defaults to `'strict-origin-when-cross-origin'`.
  final String? referrerPolicy;

  /// Value for `Content-Security-Policy`. Set to `null` to omit. Defaults to [defaultCsp].
  final String? contentSecurityPolicy;

  /// Value for `Cross-Origin-Opener-Policy`. Set to `null` to omit. Defaults to `'same-origin'`.
  final String? crossOriginOpenerPolicy;

  /// Value for `Cross-Origin-Resource-Policy`. Set to `null` to omit. Defaults to `'same-origin'`.
  final String? crossOriginResourcePolicy;

  /// Value for `Permissions-Policy`. Set to `null` to omit. Defaults to `null`.
  final String? permissionsPolicy;

  /// Max age duration for `Strict-Transport-Security` (HSTS). Defaults to 365 days.
  final Duration hstsMaxAge;

  /// Whether HSTS applies to subdomains (`includeSubDomains`). Defaults to `true`.
  final bool hstsIncludeSubDomains;

  /// Whether HSTS is flagged for browser preload (`preload`). Defaults to `false`.
  final bool hstsPreload;

  /// If `true`, HSTS headers will be added regardless of request scheme (not recommended for local dev).
  /// If `false` (default), HSTS is added ONLY if HTTPS is detected via URI scheme or `X-Forwarded-Proto`.
  final bool forceHsts;

  /// Optional extra security headers to append to all responses.
  final Map<String, String>? customHeaders;

  /// Creates a [BloomSecurityHeadersMiddleware] instance with customizable security headers.
  ///
  /// - [contentTypeOptions]: Value for `X-Content-Type-Options` (defaults to `'nosniff'`).
  /// - [frameOptions]: Value for `X-Frame-Options` (defaults to `'DENY'`).
  /// - [referrerPolicy]: Value for `Referrer-Policy` (defaults to `'strict-origin-when-cross-origin'`).
  /// - [contentSecurityPolicy]: Value for `Content-Security-Policy` (defaults to [defaultCsp]).
  /// - [crossOriginOpenerPolicy]: Value for `Cross-Origin-Opener-Policy` (defaults to `'same-origin'`).
  /// - [crossOriginResourcePolicy]: Value for `Cross-Origin-Resource-Policy` (defaults to `'same-origin'`).
  /// - [permissionsPolicy]: Optional `Permissions-Policy` header value.
  /// - [hstsMaxAge]: Max age duration for `Strict-Transport-Security` (defaults to 365 days).
  /// - [hstsIncludeSubDomains]: Whether HSTS includes subdomains (`includeSubDomains`).
  /// - [hstsPreload]: Whether HSTS includes the `preload` directive.
  /// - [forceHsts]: If `true`, HSTS headers are emitted even on non-HTTPS requests.
  /// - [customHeaders]: Extra custom response headers to append.
  ///
  /// Example:
  /// ```dart
  /// const security = BloomSecurityHeadersMiddleware(
  ///   frameOptions: 'SAMEORIGIN',
  ///   hstsPreload: true,
  /// );
  /// ```
  const BloomSecurityHeadersMiddleware({
    this.contentTypeOptions = 'nosniff',
    this.frameOptions = 'DENY',
    this.referrerPolicy = 'strict-origin-when-cross-origin',
    this.contentSecurityPolicy = defaultCsp,
    this.crossOriginOpenerPolicy = 'same-origin',
    this.crossOriginResourcePolicy = 'same-origin',
    this.permissionsPolicy,
    this.hstsMaxAge = const Duration(days: 365),
    this.hstsIncludeSubDomains = true,
    this.hstsPreload = false,
    this.forceHsts = false,
    this.customHeaders,
  });

  /// Factory preset optimized for API services (disables HTML frame embedding and sets API-focused CSP).
  ///
  /// Sets `Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
  /// and disables framing and execution with `default-src 'none'; frame-ancestors 'none'`.
  ///
  /// - [contentSecurityPolicy]: Custom CSP string (defaults to `"default-src 'none'; frame-ancestors 'none'"`).
  /// - [customHeaders]: Extra custom response headers to append.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomSecurityHeadersMiddleware.api());
  /// ```
  factory BloomSecurityHeadersMiddleware.api({
    String? contentSecurityPolicy = "default-src 'none'; frame-ancestors 'none'",
    Map<String, String>? customHeaders,
  }) {
    return BloomSecurityHeadersMiddleware(
      contentTypeOptions: 'nosniff',
      frameOptions: 'DENY',
      referrerPolicy: 'no-referrer',
      contentSecurityPolicy: contentSecurityPolicy,
      crossOriginOpenerPolicy: 'same-origin',
      crossOriginResourcePolicy: 'same-origin',
      customHeaders: customHeaders,
    );
  }

  /// Intercepts the downstream response from [next] and appends all configured security headers.
  ///
  /// Evaluates whether the incoming [request] is secure (via HTTPS URI scheme, `X-Forwarded-Proto`,
  /// or `X-Forwarded-Ssl`) before emitting `Strict-Transport-Security` headers (unless [forceHsts] is enabled).
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final response = await next();

    // 1. X-Content-Type-Options
    if (contentTypeOptions != null) {
      _setHeader(response.headers, 'X-Content-Type-Options', contentTypeOptions!);
    }

    // 2. X-Frame-Options
    if (frameOptions != null) {
      _setHeader(response.headers, 'X-Frame-Options', frameOptions!);
    }

    // 3. Referrer-Policy
    if (referrerPolicy != null) {
      _setHeader(response.headers, 'Referrer-Policy', referrerPolicy!);
    }

    // 4. Content-Security-Policy
    if (contentSecurityPolicy != null) {
      _setHeader(response.headers, 'Content-Security-Policy', contentSecurityPolicy!);
    }

    // 5. Cross-Origin-Opener-Policy
    if (crossOriginOpenerPolicy != null) {
      _setHeader(response.headers, 'Cross-Origin-Opener-Policy', crossOriginOpenerPolicy!);
    }

    // 6. Cross-Origin-Resource-Policy
    if (crossOriginResourcePolicy != null) {
      _setHeader(response.headers, 'Cross-Origin-Resource-Policy', crossOriginResourcePolicy!);
    }

    // 7. Permissions-Policy
    if (permissionsPolicy != null) {
      _setHeader(response.headers, 'Permissions-Policy', permissionsPolicy!);
    }

    // 8. Strict-Transport-Security (HSTS)
    // Only send HSTS over HTTPS or when explicitly forced, never over plain HTTP dev environments.
    if (forceHsts || _isHttps(request)) {
      final hstsParts = <String>['max-age=${hstsMaxAge.inSeconds}'];
      if (hstsIncludeSubDomains) hstsParts.add('includeSubDomains');
      if (hstsPreload) hstsParts.add('preload');
      _setHeader(response.headers, 'Strict-Transport-Security', hstsParts.join('; '));
    }

    // 9. Custom Headers
    if (customHeaders != null) {
      for (final entry in customHeaders!.entries) {
        _setHeader(response.headers, entry.key, entry.value);
      }
    }

    return response;
  }

  bool _isHttps(BloomRequest request) {
    if (request.uri.scheme.toLowerCase() == 'https') return true;

    final proto = _extractHeader(request.headers, 'x-forwarded-proto');
    if (proto != null && proto.toLowerCase().contains('https')) return true;

    final ssl = _extractHeader(request.headers, 'x-forwarded-ssl');
    if (ssl != null && ssl.toLowerCase() == 'on') return true;

    return false;
  }

  void _setHeader(Map<String, String> headers, String key, String value) {
    headers[key] = value;
    headers[key.toLowerCase()] = value;
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
