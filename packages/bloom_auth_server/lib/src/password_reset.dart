// lib/src/password_reset.dart
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'session_token.dart';

/// Exception thrown when a password reset token is invalid, expired, or tampered with.
///
/// Example:
/// ```dart
/// if (!verifyPasswordResetToken(token: token, userId: userId, currentPasswordHash: hash)) {
///   throw const PasswordResetException('Password reset token is invalid or has expired');
/// }
/// ```
class PasswordResetException implements Exception {
  /// Description of the error.
  final String message;

  /// Creates a [PasswordResetException] with the given [message].
  const PasswordResetException(this.message);

  @override
  String toString() => 'PasswordResetException: $message';
}

/// Parsed metadata extracted from a password reset token.
///
/// Contains the [userId] and [expiryUnixSeconds] parsed from the unverified token
/// payload. This enables looking up the user in a database prior to cryptographic
/// verification via [verifyPasswordResetToken].
///
/// Example:
/// ```dart
/// final payload = parsePasswordResetToken(token);
/// if (payload != null && !payload.isExpired) {
///   print('Reset requested for user: ${payload.userId}');
///   print('Expires at: ${payload.expiresAt}');
/// }
/// ```
class PasswordResetTokenPayload {
  /// The user identifier encoded in the reset token.
  final String userId;

  /// The Unix timestamp (in seconds) when this token expires.
  final int expiryUnixSeconds;

  /// The expiration [DateTime] in UTC.
  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch(expiryUnixSeconds * 1000,
          isUtc: true);

  /// Whether this token has passed its expiration time.
  bool get isExpired =>
      DateTime.now().toUtc().millisecondsSinceEpoch >= expiryUnixSeconds * 1000;

  /// Creates a [PasswordResetTokenPayload] with [userId] and [expiryUnixSeconds].
  const PasswordResetTokenPayload({
    required this.userId,
    required this.expiryUnixSeconds,
  });
}

/// Generates a single-purpose, signed, time-limited password reset token.
///
/// Mirrors the security design of `djangors-auth`'s `generate_password_reset_token`:
/// 1. Binds cryptographically to [userId], token expiration, and a prefix of the
///    user's [currentPasswordHash]. When the user changes their password, all existing
///    reset tokens are immediately rendered invalid.
/// 2. Explicitly prefixes the HMAC message with `bloom_pwd_reset:` to guarantee domain
///    separation — ensuring reset tokens cannot be accepted as bearer session tokens.
/// 3. Returns a URL-safe token format: `rst.<b64_user_id>.<b64_expiry>.<b64_mac>`.
///
/// [ttl] defines token lifespan (defaults to 1 hour).
/// [secret] defaults to `BloomEnv.get('BLOOM_AUTH_SECRET')` via [resolveAuthSecret].
///
/// Throws [ArgumentError] if [userId] or [currentPasswordHash] is empty.
/// Throws [StateError] if no secret is provided and none is configured in `BloomEnv`.
///
/// Example:
/// ```dart
/// final token = generatePasswordResetToken(
///   userId: user.id,
///   currentPasswordHash: user.passwordHash,
///   ttl: const Duration(minutes: 30),
/// );
/// await emailService.sendPasswordResetEmail(user.email, token);
/// ```
String generatePasswordResetToken({
  required String userId,
  required String currentPasswordHash,
  Duration ttl = const Duration(hours: 1),
  String? secret,
}) {
  if (userId.isEmpty) {
    throw ArgumentError.value(userId, 'userId', 'userId cannot be empty');
  }
  if (currentPasswordHash.isEmpty) {
    throw ArgumentError.value(
      currentPasswordHash,
      'currentPasswordHash',
      'currentPasswordHash cannot be empty',
    );
  }
  if (ttl.isNegative || ttl == Duration.zero || ttl.inSeconds <= 0) {
    throw ArgumentError.value(
      ttl,
      'ttl',
      'Password reset TTL must be strictly positive',
    );
  }

  final signingKey = resolveAuthSecret(secret);
  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final expiryUnixSecs = nowSecs + ttl.inSeconds;

  final b64UserId = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
  final b64Expiry = base64Url
      .encode(utf8.encode(expiryUnixSecs.toString()))
      .replaceAll('=', '');

  final prefixLen =
      currentPasswordHash.length < 30 ? currentPasswordHash.length : 30;
  final hashPrefix = currentPasswordHash.substring(0, prefixLen);

  final message = 'bloom_pwd_reset:$userId:$expiryUnixSecs:$hashPrefix';
  final hmac = Hmac(sha256, utf8.encode(signingKey));
  final digest = hmac.convert(utf8.encode(message));
  final b64Mac = base64Url.encode(digest.bytes).replaceAll('=', '');

  return 'rst.$b64UserId.$b64Expiry.$b64Mac';
}

/// Parses the user ID and expiration from a password reset token without verifying the signature.
///
/// Use this to extract [userId] in order to look up the user and retrieve their
/// current password hash before calling [verifyPasswordResetToken].
///
/// Returns `null` if the [token] string is malformed or lacks the `rst.` prefix.
///
/// Example:
/// ```dart
/// final payload = parsePasswordResetToken(token);
/// if (payload == null || payload.isExpired) {
///   return BloomResponse.badRequest('Invalid or expired reset token');
/// }
///
/// final user = await userDb.findById(payload.userId);
/// if (user == null) {
///   return BloomResponse.badRequest('User not found');
/// }
///
/// final isValid = verifyPasswordResetToken(
///   token: token,
///   userId: user.id,
///   currentPasswordHash: user.passwordHash,
/// );
/// ```
PasswordResetTokenPayload? parsePasswordResetToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 4 || parts[0] != 'rst') {
      return null;
    }

    final paddedUserId = _padBase64(parts[1]);
    final userId = utf8.decode(base64Url.decode(paddedUserId));

    final paddedExpiry = _padBase64(parts[2]);
    final expiryStr = utf8.decode(base64Url.decode(paddedExpiry));
    final expiryUnixSecs = int.tryParse(expiryStr);

    if (expiryUnixSecs == null) return null;

    return PasswordResetTokenPayload(
      userId: userId,
      expiryUnixSeconds: expiryUnixSecs,
    );
  } catch (_) {
    return null;
  }
}

/// Verifies a password reset token against a user's [currentPasswordHash] and secret.
///
/// Returns `true` only if:
/// 1. The token format is valid and has the `rst.` type prefix.
/// 2. The token has not expired.
/// 3. The token was generated for the specified [userId].
/// 4. The user's password hash has not changed since the token was issued.
/// 5. The HMAC-SHA256 signature matches using the server [secret].
///
/// Uses constant-time string comparison to prevent timing attacks.
///
/// Example:
/// ```dart
/// final isValid = verifyPasswordResetToken(
///   token: token,
///   userId: user.id,
///   currentPasswordHash: user.passwordHash,
/// );
/// if (!isValid) {
///   return BloomResponse.badRequest('Reset token is invalid, expired, or already used');
/// }
///
/// // Update user password in database...
/// ```
bool verifyPasswordResetToken({
  required String token,
  required String userId,
  required String currentPasswordHash,
  String? secret,
}) {
  if (token.isEmpty || userId.isEmpty || currentPasswordHash.isEmpty) {
    return false;
  }

  try {
    final parts = token.split('.');
    if (parts.length != 4 || parts[0] != 'rst') {
      return false;
    }

    final signingKey = resolveAuthSecret(secret);

    // Decode and verify userId
    final paddedUserId = _padBase64(parts[1]);
    final tokenUserId = utf8.decode(base64Url.decode(paddedUserId));
    if (tokenUserId != userId) {
      return false;
    }

    // Decode and verify expiry
    final paddedExpiry = _padBase64(parts[2]);
    final expiryStr = utf8.decode(base64Url.decode(paddedExpiry));
    final expiryUnixSecs = int.tryParse(expiryStr);
    if (expiryUnixSecs == null) {
      return false;
    }

    final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (expiryUnixSecs <= nowSecs) {
      return false;
    }

    // Verify HMAC
    final prefixLen =
        currentPasswordHash.length < 30 ? currentPasswordHash.length : 30;
    final hashPrefix = currentPasswordHash.substring(0, prefixLen);
    final message = 'bloom_pwd_reset:$userId:$expiryUnixSecs:$hashPrefix';

    final hmac = Hmac(sha256, utf8.encode(signingKey));
    final expectedDigest = hmac.convert(utf8.encode(message));
    final expectedB64Mac =
        base64Url.encode(expectedDigest.bytes).replaceAll('=', '');

    // Constant-time string equality check to prevent timing leaks
    return _constantTimeCompare(parts[3], expectedB64Mac);
  } catch (_) {
    return false;
  }
}

/// Constant-time comparison between two strings to prevent timing attacks.
bool _constantTimeCompare(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (aBytes.length != bBytes.length) return false;

  var result = 0;
  for (var i = 0; i < aBytes.length; i++) {
    result |= aBytes[i] ^ bBytes[i];
  }
  return result == 0;
}

String _padBase64(String str) {
  final remainder = str.length % 4;
  if (remainder == 2) return '$str==';
  if (remainder == 3) return '$str=';
  return str;
}

/// Interface for tracking consumed or revoked password reset tokens.
///
/// While Bloom's password reset tokens are cryptographically bound to the user's password
/// hash (which automatically invalidates outstanding reset tokens once a new password hash is stored),
/// a revocation store provides stateful single-use guarantees *before* or independently of the password change.
abstract interface class BloomPasswordResetRevocationStore {
  /// Records a [token] as used/revoked until [expiresAt].
  FutureOr<void> recordRevoked(String token, {required DateTime expiresAt});

  /// Returns `true` if the [token] has already been consumed or revoked.
  FutureOr<bool> isRevoked(String token);
}

/// In-memory implementation of [BloomPasswordResetRevocationStore] with automatic expiration cleanup.
class InMemoryPasswordResetRevocationStore
    implements BloomPasswordResetRevocationStore {
  final Map<String, DateTime> _revokedTokens = {};

  @override
  FutureOr<void> recordRevoked(String token, {required DateTime expiresAt}) {
    _prune();
    _revokedTokens[token] = expiresAt;
  }

  @override
  FutureOr<bool> isRevoked(String token) {
    _prune();
    return _revokedTokens.containsKey(token);
  }

  void _prune() {
    final now = DateTime.now().toUtc();
    _revokedTokens.removeWhere((_, exp) => now.isAfter(exp));
  }

  /// Number of active revoked token records.
  int get count {
    _prune();
    return _revokedTokens.length;
  }
}

/// Verifies a password reset token and atomically consumes/revokes it via [revocationStore].
///
/// Returns `true` only if:
/// 1. The token has not already been marked as revoked/consumed in [revocationStore].
/// 2. [verifyPasswordResetToken] succeeds with valid signature, non-expired TTL, and matching password hash.
///
/// Upon successful verification, records the token in [revocationStore] so subsequent attempts fail.
Future<bool> verifyAndConsumePasswordResetToken({
  required String token,
  required String userId,
  required String currentPasswordHash,
  required BloomPasswordResetRevocationStore revocationStore,
  String? secret,
}) async {
  if (await revocationStore.isRevoked(token)) {
    return false;
  }

  final isValid = verifyPasswordResetToken(
    token: token,
    userId: userId,
    currentPasswordHash: currentPasswordHash,
    secret: secret,
  );

  if (!isValid) return false;

  final payload = parsePasswordResetToken(token);
  if (payload != null) {
    await revocationStore.recordRevoked(token, expiresAt: payload.expiresAt);
  }

  return true;
}
