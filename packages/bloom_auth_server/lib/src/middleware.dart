// lib/src/middleware.dart
import 'dart:async';
import 'package:bloom_server/bloom_server.dart';
import 'session_token.dart';

/// Private Expando storing verified [BloomAuthClaims] attached to [BloomRequest] instances.
final Expando<BloomAuthClaims> _authClaimsExpando =
    Expando<BloomAuthClaims>('BloomAuthClaims');

/// Server-side authentication verification middleware for Bloom applications.
///
/// Extracts the Bearer token from incoming HTTP `Authorization` headers, verifies
/// the cryptographic HMAC-SHA256 signature, validates expiration, attaches the
/// decoded [BloomAuthClaims] to the [BloomRequest], and enforces optional role requirements.
///
/// Returns HTTP 401 Unauthorized for missing, malformed, or expired tokens, and
/// HTTP 403 Forbidden when required roles are not met.
///
/// Example:
/// ```dart
/// final router = BloomApiRouter();
///
/// // Protect all routes with authentication
/// router.use(const BloomAuthMiddleware());
///
/// // Or protect specific route groups by role
/// router.group('/admin', (adminRouter) {
///   adminRouter.use(BloomAuthMiddleware.requireRole('admin'));
///   adminRouter.get('/users', (req) async {
///     return BloomResponse.json({'adminId': req.authUserId});
///   });
/// });
/// ```
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
  /// [requiredRoles] specifies roles the user must possess (any match authorizes access).
  /// [optional] allows unauthenticated requests to pass through if `true`.
  ///
  /// Example:
  /// ```dart
  /// router.use(const BloomAuthMiddleware());
  /// ```
  const BloomAuthMiddleware({
    this.secret,
    this.requiredRoles = const [],
    this.optional = false,
  });

  /// Creates a middleware instance that requires a specific [role] (e.g. `'admin'`).
  ///
  /// Rejects requests from users without the specified role with HTTP 403 Forbidden.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAuthMiddleware.requireRole('admin'));
  /// ```
  factory BloomAuthMiddleware.requireRole(String role, {String? secret}) =>
      BloomAuthMiddleware(
        secret: secret,
        requiredRoles: [role],
        optional: false,
      );

  /// Creates a middleware instance that requires any of the specified [roles].
  ///
  /// Access is granted if the user possesses at least one role in [roles].
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAuthMiddleware.requireAnyRole(['admin', 'moderator']));
  /// ```
  factory BloomAuthMiddleware.requireAnyRole(List<String> roles,
          {String? secret}) =>
      BloomAuthMiddleware(
        secret: secret,
        requiredRoles: roles,
        optional: false,
      );

  /// Creates an optional authentication middleware.
  ///
  /// Requests without an `Authorization` header are allowed through with `request.auth == null`.
  /// Requests providing an invalid or expired token are still rejected with HTTP 401 Unauthorized.
  ///
  /// Example:
  /// ```dart
  /// router.use(BloomAuthMiddleware.optional());
  /// router.get('/feed', (req) async {
  ///   if (req.isAuthenticated) {
  ///     return BloomResponse.json({'feed': 'personalized', 'user': req.authUserId});
  ///   }
  ///   return BloomResponse.json({'feed': 'public'});
  /// });
  /// ```
  factory BloomAuthMiddleware.optional({String? secret}) => BloomAuthMiddleware(
        secret: secret,
        optional: true,
      );

  /// Intercepts [request], parses and validates Bearer token, checks [requiredRoles],
  /// and forwards to [next] or returns an error [BloomResponse].
  @override
  Future<BloomResponse?> handle(
      BloomRequest request, BloomNextFunction next) async {
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
    if (parts.length != 2 ||
        parts[0].toLowerCase() != 'bearer' ||
        parts[1].isEmpty) {
      return BloomResponse.unauthorized(
          'Invalid Authorization format. Expected "Bearer <token>"');
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
        return BloomResponse.unauthorized(
            'Session token has expired. Please log in again.');
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
///
/// Provides ergonomic access to the decoded [BloomAuthClaims], user ID, authentication state,
/// and role membership from request handlers.
///
/// Example:
/// ```dart
/// router.get('/profile', (req) async {
///   if (!req.isAuthenticated) {
///     return BloomResponse.unauthorized('Please log in');
///   }
///
///   final userId = req.authUserId!;
///   final isManager = req.hasRole('manager');
///   return BloomResponse.json({'userId': userId, 'isManager': isManager});
/// });
/// ```
extension BloomAuthRequestExtension on BloomRequest {
  /// Returns the verified [BloomAuthClaims] attached by [BloomAuthMiddleware],
  /// or `null` if the request is unauthenticated.
  ///
  /// Example:
  /// ```dart
  /// final claims = req.auth;
  /// if (claims != null) {
  ///   print('Email: ${claims.email}');
  /// }
  /// ```
  BloomAuthClaims? get auth => _authClaimsExpando[this];

  /// Returns the authenticated user's ID, or `null` if unauthenticated.
  ///
  /// Strictly returns the user ID from cryptographically verified claims
  /// attached by [BloomAuthMiddleware]. Never falls back to mutable request params.
  ///
  /// Example:
  /// ```dart
  /// final userId = req.authUserId;
  /// ```
  String? get authUserId => auth?.userId;

  /// Whether this request has been successfully authenticated.
  ///
  /// Example:
  /// ```dart
  /// if (req.isAuthenticated) {
  ///   // User is logged in
  /// }
  /// ```
  bool get isAuthenticated => auth != null;

  /// Returns whether the authenticated user possesses the specified [role].
  ///
  /// Strictly checks against cryptographically verified claims.
  ///
  /// Example:
  /// ```dart
  /// if (req.hasRole('admin')) {
  ///   // Allow admin action
  /// }
  /// ```
  bool hasRole(String role) => auth?.hasRole(role) ?? false;

  /// Returns whether the authenticated user possesses any of the specified [roles].
  ///
  /// Strictly checks against cryptographically verified claims.
  bool hasAnyRole(Iterable<String> roles) => auth?.hasAnyRole(roles) ?? false;

  /// Returns the list of verified roles assigned to the authenticated user.
  List<String> get authRoles => auth?.roles ?? const [];
}
