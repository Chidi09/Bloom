// lib/src/middleware.dart
import 'dart:async';
import 'package:bloom_server/bloom_server.dart';
import 'session_token.dart';

/// Private Expando storing verified [BloomAuthClaims] attached to [BloomRequest] instances.
final Expando<BloomAuthClaims> _authClaimsExpando = Expando<BloomAuthClaims>('BloomAuthClaims');

/// Server-side authentication verification middleware for Bloom applications.
///
/// Extracts the Bearer token from incoming HTTP `Authorization` headers, verifies
/// the cryptographic HMAC-SHA256 signature, validates expiration, attaches the
/// decoded [BloomAuthClaims] to the [BloomRequest], and enforces optional role requirements.
///
/// Returns HTTP 401 Unauthorized for missing, malformed, or expired tokens, and
/// HTTP 403 Forbidden when required roles are not met.
class BloomAuthMiddleware implements BloomMiddleware {
  /// Optional HMAC secret override used to verify session tokens.
  /// If not provided, defaults to resolving via [resolveAuthSecret].
  final String? secret;

  /// Optional list of required roles. If specified, the authenticated user
  /// must possess at least one of these roles to access the route.
  final List<String> requiredRoles;

  /// Whether authentication is optional. When `true`, unauthenticated requests
  /// proceed with `request.auth == null`.
  final bool optional;

  /// Creates a [BloomAuthMiddleware] instance.
  ///
  /// [secret] is the optional HMAC secret override.
  /// [requiredRoles] specifies roles the user must possess.
  /// [optional] allows unauthenticated requests to pass through if `true`.
  const BloomAuthMiddleware({
    this.secret,
    this.requiredRoles = const [],
    this.optional = false,
  });

  /// Creates a middleware instance that requires a specific [role] (e.g. 'admin').
  factory BloomAuthMiddleware.requireRole(String role, {String? secret}) =>
      BloomAuthMiddleware(
        secret: secret,
        requiredRoles: [role],
        optional: false,
      );

  /// Creates a middleware instance that requires any of the specified [roles].
  factory BloomAuthMiddleware.requireAnyRole(List<String> roles, {String? secret}) =>
      BloomAuthMiddleware(
        secret: secret,
        requiredRoles: roles,
        optional: false,
      );

  /// Creates an optional authentication middleware.
  ///
  /// Requests without an Authorization header are allowed through with `request.auth == null`.
  /// Requests providing an invalid or expired token are still rejected with HTTP 401.
  factory BloomAuthMiddleware.optional({String? secret}) =>
      BloomAuthMiddleware(
        secret: secret,
        optional: true,
      );

  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final authHeader = request.headers['authorization'] ??
        request.headers['Authorization'] ??
        request.headers['AUTHORIZATION'];

    if (authHeader == null || authHeader.trim().isEmpty) {
      if (optional) {
        return await next();
      }
      return BloomResponse.unauthorized('Missing Authorization header');
    }

    final trimmed = authHeader.trim();
    final parts = trimmed.split(' ');
    if (parts.length != 2 || parts[0].toLowerCase() != 'bearer' || parts[1].isEmpty) {
      return BloomResponse.unauthorized('Invalid Authorization format. Expected "Bearer <token>"');
    }

    final tokenStr = parts[1].trim();

    // Only the token-verification step belongs inside this try/catch.
    // `next()` runs the rest of the middleware chain and the route handler
    // itself — wrapping it here would mean any unrelated exception thrown
    // deep in the pipeline (e.g. a typed bloom_errors exception meant to
    // become a 404/422/500 via BloomErrorMiddleware) gets caught by this
    // middleware first and misreported as a 401 auth failure.
    final BloomAuthClaims claims;
    try {
      claims = verifySessionToken(tokenStr, secret: secret);
    } on SessionTokenException catch (e) {
      if (e.isExpired) {
        return BloomResponse.unauthorized('Session token has expired. Please log in again.');
      }
      return BloomResponse.unauthorized('Invalid session token: ${e.message}');
    } catch (_) {
      return BloomResponse.unauthorized('Authentication verification failed');
    }

    // Verify required roles if specified
    if (requiredRoles.isNotEmpty) {
      final hasRequiredRole = requiredRoles.any((r) => claims.hasRole(r));
      if (!hasRequiredRole) {
        return BloomResponse.forbidden(
          'Forbidden: Account lacks required role (${requiredRoles.join(", ")})',
        );
      }
    }

    // Attach verified claims to the request instance via Expando
    _authClaimsExpando[request] = claims;

    // Populate convenience request params
    request.params['auth_user_id'] = claims.userId;
    request.params['auth_roles'] = claims.roles.join(',');

    return await next();
  }
}

/// Convenience extension on [BloomRequest] to access verified authentication context.
extension BloomAuthRequestExtension on BloomRequest {
  /// Returns the verified [BloomAuthClaims] attached by [BloomAuthMiddleware],
  /// or `null` if the request is unauthenticated.
  BloomAuthClaims? get auth => _authClaimsExpando[this];

  /// Returns the authenticated user's ID, or `null` if unauthenticated.
  String? get authUserId => auth?.userId ?? params['auth_user_id'];

  /// Whether this request has been successfully authenticated.
  bool get isAuthenticated => auth != null;

  /// Returns whether the authenticated user possesses the specified [role].
  bool hasRole(String role) => auth?.hasRole(role) ?? false;
}
