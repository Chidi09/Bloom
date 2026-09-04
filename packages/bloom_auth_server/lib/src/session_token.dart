// lib/src/session_token.dart
import 'package:bloom_server/bloom_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Exception thrown when session token verification fails.
///
/// Indicates an invalid HMAC signature, expired session lifespan, malformed payload structure,
/// or token type mismatch (e.g. attempting to use a reset token as a session token).
///
/// Example:
/// ```dart
/// try {
///   final claims = verifySessionToken(bearerToken);
/// } on SessionTokenException catch (e) {
///   if (e.isExpired) {
///     print('Session has expired. Prompting user to re-authenticate.');
///   } else {
///     print('Invalid token: ${e.message}');
///   }
/// }
/// ```
class SessionTokenException implements Exception {
  /// Description of the error.
  final String message;

  /// Whether the failure occurred specifically because the token expired.
  final bool isExpired;

  /// The underlying cause or exception, if any.
  final dynamic cause;

  /// Creates a [SessionTokenException] with [message], optional [isExpired] flag, and optional [cause].
  const SessionTokenException(
    this.message, {
    this.isExpired = false,
    this.cause,
  });

  @override
  String toString() =>
      'SessionTokenException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Reserved JWT/session claim keys that [customClaims] must not override.
///
/// Keeping this as a single source of truth so issuance ([issueSessionToken]),
/// parsing ([BloomAuthClaims.fromJwtPayload]), and serialization
/// ([BloomAuthClaims.toMap]) agree on which keys are identity-critical.
const reservedSessionClaimKeys = {
  'sub',
  'userId',
  'email',
  'roles',
  'role',
  'token_type',
  'iat',
  'exp',
  'nbf',
  'iss',
  'aud',
};

/// Strongly-typed claims extracted from an authenticated session token.
///
/// Encapsulates user identity ([userId], [email]), authorization privileges ([roles]),
/// token lifetime timestamps ([issuedAt], [expiresAt]), and any arbitrary application metadata
/// in [customClaims].
///
/// Example:
/// ```dart
/// final claims = verifySessionToken(token);
/// print('User: ${claims.userId}');
/// if (claims.hasRole('admin')) {
///   // Grant administrative access
/// }
/// ```
class BloomAuthClaims {
  /// The unique identifier of the authenticated user.
  final String userId;

  /// Optional email address of the authenticated user.
  final String? email;

  /// Optional role list assigned to the authenticated user.
  final List<String> roles;

  /// The timestamp when the token was issued.
  final DateTime issuedAt;

  /// The timestamp when the token expires.
  final DateTime expiresAt;

  /// Additional custom claims included in the payload.
  final Map<String, dynamic> customClaims;

  /// Creates a [BloomAuthClaims] instance representing verified JWT session claims.
  const BloomAuthClaims({
    required this.userId,
    this.email,
    this.roles = const [],
    required this.issuedAt,
    required this.expiresAt,
    this.customClaims = const {},
  });

  /// Factory constructor to parse claims from a decoded JWT payload [payload].
  ///
  /// Extracts the subject (`sub` or `userId`), optional `email`, `roles` (or single `role`),
  /// timestamps (`iat`, `exp`), and partitions any non-reserved claims into [customClaims].
  ///
  /// Throws [SessionTokenException] if neither `sub` nor `userId` is present.
  ///
  /// Example:
  /// ```dart
  /// final claims = BloomAuthClaims.fromJwtPayload({
  ///   'sub': 'usr_456',
  ///   'email': 'dev@example.com',
  ///   'roles': ['editor'],
  ///   'iat': 1700000000,
  ///   'exp': 1700604800,
  ///   'orgId': 'org_99',
  /// });
  /// print(claims.customClaims['orgId']); // 'org_99'
  /// ```
  factory BloomAuthClaims.fromJwtPayload(Map<String, dynamic> payload) {
    final sub = payload['sub']?.toString() ?? payload['userId']?.toString();
    if (sub == null || sub.isEmpty) {
      throw const SessionTokenException(
          'JWT payload missing subject ("sub") or "userId" claim');
    }

    final email = payload['email']?.toString();

    final rawRoles = payload['roles'];
    final List<String> roles = [];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r != null) roles.add(r.toString());
      }
    } else if (payload['role'] != null) {
      roles.add(payload['role'].toString());
    }

    DateTime issuedAt;
    final iat = payload['iat'];
    if (iat is num) {
      issuedAt =
          DateTime.fromMillisecondsSinceEpoch(iat.toInt() * 1000, isUtc: true);
    } else {
      issuedAt = DateTime.now().toUtc();
    }

    DateTime expiresAt;
    final exp = payload['exp'];
    if (exp is! num) {
      throw const SessionTokenException(
          'JWT payload missing a valid "exp" expiration claim');
    }
    expiresAt =
        DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);

    final custom = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (!reservedSessionClaimKeys.contains(entry.key)) {
        custom[entry.key] = entry.value;
      }
    }

    return BloomAuthClaims(
      userId: sub,
      email: email,
      roles: List.unmodifiable(roles),
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      customClaims: Map.unmodifiable(custom),
    );
  }

  /// Whether this user has a specific [role].
  ///
  /// Example:
  /// ```dart
  /// if (claims.hasRole('admin')) {
  ///   // User is an administrator
  /// }
  /// ```
  bool hasRole(String role) => roles.contains(role);

  /// Whether this user has any of the specified [requiredRoles].
  ///
  /// Example:
  /// ```dart
  /// if (claims.hasAnyRole(['admin', 'superadmin', 'owner'])) {
  ///   // User possesses at least one authorized role
  /// }
  /// ```
  bool hasAnyRole(Iterable<String> requiredRoles) =>
      requiredRoles.any((r) => roles.contains(r));

  /// Converts claims to a JSON-serializable [Map].
  ///
  /// Example:
  /// ```dart
  /// final claimsMap = claims.toMap();
  /// print(claimsMap['userId']);
  /// ```
  Map<String, dynamic> toMap() => {
        // Spread custom first so verified identity keys always win, even if
        // a stale/custom map ever contains a reserved key.
        ...customClaims,
        'userId': userId,
        if (email != null) 'email': email,
        'roles': roles,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  @override
  String toString() =>
      'BloomAuthClaims(userId: $userId, email: $email, roles: $roles)';
}

/// Resolves the HMAC signing secret from parameter or [BloomEnv].
/// Never hardcodes fallback secrets in production.
///
/// Priority order:
/// 1. Explicit [secret] argument passed to the function.
/// 2. `BLOOM_AUTH_SECRET` environment variable via [BloomEnv].
/// 3. `JWT_SECRET` environment variable via [BloomEnv].
/// 4. `AUTH_SECRET` environment variable via [BloomEnv].
///
/// Throws [StateError] if no secret argument is supplied and none is found in [BloomEnv].
///
/// Example:
/// ```dart
/// final signingSecret = resolveAuthSecret();
/// ```
String resolveAuthSecret([String? secret]) {
  if (secret != null && secret.isNotEmpty) {
    return secret;
  }

  final envSecret = BloomEnv.getOrNull('BLOOM_AUTH_SECRET') ??
      BloomEnv.getOrNull('JWT_SECRET') ??
      BloomEnv.getOrNull('AUTH_SECRET');

  if (envSecret != null && envSecret.isNotEmpty) {
    return envSecret;
  }

  throw StateError(
    'BloomAuthServer: No authentication signing secret found. '
    'Provide a secret argument or configure "BLOOM_AUTH_SECRET" via BloomEnv.',
  );
}

/// Issues a cryptographically signed HMAC-SHA256 JWT bearer session token.
///
/// Embeds [userId] as subject (`sub`), optional [email], [roles], and [customClaims],
/// explicitly tagged with `token_type: 'session'` to prevent token substitution attacks.
///
/// [ttl] defines token lifespan (defaults to 7 days).
/// [issuer] sets the JWT `iss` claim (defaults to `'bloom-auth-server'`).
/// [secret] defaults to resolving via [resolveAuthSecret].
///
/// Throws [ArgumentError] if [userId] is empty, or if [customClaims] contains
/// a reserved identity key (`sub`, `userId`, `email`, `roles`, `role`,
/// `token_type`, `iat`, `exp`, `nbf`, `iss`, `aud`). Reserved keys are never
/// taken from [customClaims]; pass them via the dedicated parameters instead.
/// Throws [StateError] if no secret is provided and none is found via [BloomEnv].
///
/// Example:
/// ```dart
/// final token = issueSessionToken(
///   userId: 'usr_123',
///   email: 'alex@example.com',
///   roles: ['admin', 'editor'],
///   customClaims: {'tenantId': 'tenant_abc'},
///   ttl: const Duration(hours: 24),
/// );
/// ```
String issueSessionToken({
  required String userId,
  String? email,
  List<String>? roles,
  Map<String, dynamic>? customClaims,
  Duration ttl = const Duration(days: 7),
  String? issuer = 'bloom-auth-server',
  String? secret,
}) {
  if (userId.isEmpty) {
    throw ArgumentError.value(userId, 'userId', 'userId cannot be empty');
  }

  final signingKey = resolveAuthSecret(secret);

  if (customClaims != null) {
    final collision = customClaims.keys.where(
      (k) => reservedSessionClaimKeys.contains(k),
    );
    if (collision.isNotEmpty) {
      throw ArgumentError.value(
        customClaims,
        'customClaims',
        'customClaims contains reserved claim key(s): ${collision.join(', ')}. '
            'Use the dedicated userId/email/roles parameters instead.',
      );
    }
  }

  final payload = <String, dynamic>{
    // Spread caller claims first so reserved identity keys below always win,
    // even if a future reserved key is missed by the guard above.
    if (customClaims != null) ...customClaims,
    'sub': userId,
    'token_type': 'session',
    if (email != null && email.isNotEmpty) 'email': email,
    if (roles != null && roles.isNotEmpty) 'roles': roles,
  };

  final jwt = JWT(
    payload,
    issuer: issuer,
  );

  return jwt.sign(SecretKey(signingKey), expiresIn: ttl);
}

/// Verifies an HMAC-SHA256 JWT session token and returns decoded [BloomAuthClaims].
///
/// Ensures the token signature is valid, unexpired, matches [issuer] if provided,
/// and is explicitly marked as `token_type: 'session'`.
///
/// [secret] defaults to resolving via [resolveAuthSecret].
///
/// Throws [SessionTokenException] if verification fails or if [token] is empty.
/// Throws [StateError] if no secret is provided and none is found via [BloomEnv].
///
/// Example:
/// ```dart
/// try {
///   final claims = verifySessionToken(tokenString);
///   print('Authenticated userId: ${claims.userId}');
/// } on SessionTokenException catch (e) {
///   print('Authentication failed: ${e.message}');
/// }
/// ```
BloomAuthClaims verifySessionToken(
  String token, {
  String? secret,
  String? issuer = 'bloom-auth-server',
}) {
  if (token.isEmpty) {
    throw const SessionTokenException('Token string is empty');
  }

  final signingKey = resolveAuthSecret(secret);

  try {
    final jwt = JWT.verify(
      token,
      SecretKey(signingKey),
      issuer: issuer,
    );

    final payload = jwt.payload;
    if (payload is! Map) {
      throw const SessionTokenException(
          'Invalid JWT payload: expected JSON map object');
    }

    final payloadMap = Map<String, dynamic>.from(payload);

    // Prevent token reuse / type substitution attacks (e.g. using password reset token as session)
    // token_type must be present and exactly equal to 'session'.
    final tokenType = payloadMap['token_type']?.toString();
    if (tokenType != 'session') {
      throw SessionTokenException(
        'Invalid token type: expected "session" token, got "${tokenType ?? "null"}"',
      );
    }

    // Issued session tokens always carry exp. Accepting a missing value here
    // would make hand-crafted signed tokens live for the parser's fallback
    // duration instead of being rejected as malformed sessions.
    if (payloadMap['exp'] is! num) {
      throw const SessionTokenException(
          'JWT payload missing a valid "exp" expiration claim');
    }

    return BloomAuthClaims.fromJwtPayload(payloadMap);
  } on JWTExpiredException catch (e) {
    throw SessionTokenException(
      'Session token has expired',
      isExpired: true,
      cause: e,
    );
  } on JWTException catch (e) {
    throw SessionTokenException(
      'Invalid session token signature or structure: ${e.message}',
      cause: e,
    );
  } catch (e) {
    if (e is SessionTokenException) rethrow;
    throw SessionTokenException(
      'Failed to verify session token: $e',
      cause: e,
    );
  }
}

/// Attempts to verify a session token, returning `null` instead of throwing on invalid/expired tokens.
///
/// Convenient for optional authentication flows where unauthenticated requests are permitted.
///
/// Example:
/// ```dart
/// final claims = tryVerifySessionToken(bearerToken);
/// if (claims != null) {
///   // User is authenticated
/// } else {
///   // Anonymous visitor
/// }
/// ```
BloomAuthClaims? tryVerifySessionToken(
  String? token, {
  String? secret,
  String? issuer = 'bloom-auth-server',
}) {
  if (token == null || token.isEmpty) return null;
  try {
    return verifySessionToken(token, secret: secret, issuer: issuer);
  } catch (_) {
    return null;
  }
}
