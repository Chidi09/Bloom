// lib/src/session_token.dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Exception thrown when session token verification fails.
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

/// Strongly-typed claims extracted from an authenticated session token.
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

  /// Factory constructor to parse claims from a decoded JWT payload.
  factory BloomAuthClaims.fromJwtPayload(Map<String, dynamic> payload) {
    final sub = payload['sub']?.toString() ?? payload['userId']?.toString();
    if (sub == null || sub.isEmpty) {
      throw const SessionTokenException('JWT payload missing subject ("sub") or "userId" claim');
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
      issuedAt = DateTime.fromMillisecondsSinceEpoch(iat.toInt() * 1000, isUtc: true);
    } else {
      issuedAt = DateTime.now().toUtc();
    }

    DateTime expiresAt;
    final exp = payload['exp'];
    if (exp is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    } else {
      expiresAt = issuedAt.add(const Duration(days: 7));
    }

    final reservedKeys = {'sub', 'userId', 'email', 'roles', 'role', 'iat', 'exp', 'nbf', 'iss', 'aud', 'token_type'};
    final custom = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (!reservedKeys.contains(entry.key)) {
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

  /// Whether this user has a specific role.
  bool hasRole(String role) => roles.contains(role);

  /// Whether this user has any of the specified roles.
  bool hasAnyRole(Iterable<String> requiredRoles) =>
      requiredRoles.any((r) => roles.contains(r));

  /// Converts claims to a JSON-serializable Map.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        if (email != null) 'email': email,
        'roles': roles,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        ...customClaims,
      };

  @override
  String toString() => 'BloomAuthClaims(userId: $userId, email: $email, roles: $roles)';
}

/// Resolves the HMAC signing secret from parameter or [BloomEnv].
/// Never hardcodes fallback secrets in production.
///
/// Throws [StateError] if no secret argument is supplied and none is found in [BloomEnv].
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
/// [secret] defaults to `BloomEnv.get('BLOOM_AUTH_SECRET')`.
///
/// Throws [ArgumentError] if [userId] is empty.
/// Throws [StateError] if no secret is provided and none is found via [BloomEnv].
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

  final payload = <String, dynamic>{
    'sub': userId,
    'token_type': 'session',
    if (email != null && email.isNotEmpty) 'email': email,
    if (roles != null && roles.isNotEmpty) 'roles': roles,
    if (customClaims != null) ...customClaims,
  };

  final jwt = JWT(
    payload,
    issuer: issuer,
  );

  return jwt.sign(SecretKey(signingKey), expiresIn: ttl);
}

/// Verifies an HMAC-SHA256 JWT session token and returns decoded [BloomAuthClaims].
///
/// Ensures the token signature is valid, unexpired, and explicitly marked as `token_type: 'session'`.
///
/// Throws [SessionTokenException] if verification fails or if the token is empty.
/// Throws [StateError] if no secret is provided and none is found via [BloomEnv].
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
      throw const SessionTokenException('Invalid JWT payload: expected JSON map object');
    }

    final payloadMap = Map<String, dynamic>.from(payload);

    // Prevent token reuse / type substitution attacks (e.g. using password reset token as session)
    final tokenType = payloadMap['token_type']?.toString();
    if (tokenType != null && tokenType != 'session') {
      throw SessionTokenException(
        'Invalid token type: expected "session" token, got "$tokenType"',
      );
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
