// lib/src/password.dart
import 'package:bcrypt/bcrypt.dart';

/// Exception thrown when password hashing or verification encounters an unexpected error.
///
/// Wraps lower-level cryptography failures while preserving the underlying [cause].
///
/// Example:
/// ```dart
/// try {
///   final hash = hashPassword(userInputPassword, cost: 12);
/// } on PasswordHashException catch (e) {
///   print('Hashing error: ${e.message}');
///   if (e.cause != null) {
///     print('Underlying cause: ${e.cause}');
///   }
/// }
/// ```
class PasswordHashException implements Exception {
  /// Description of the error.
  final String message;

  /// The underlying cause or exception, if any.
  final dynamic cause;

  /// Creates a [PasswordHashException] with a [message] and optional [cause].
  const PasswordHashException(this.message, [this.cause]);

  @override
  String toString() =>
      'PasswordHashException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Cached dummy hashes indexed by BCrypt work factor.
final Map<int, String> _dummyBcryptHashes = {};

/// Hashes a plaintext [password] using OpenBSD BCrypt with a secure random salt.
///
/// [cost] specifies the log2 work factor (default is `12`, recommended for modern servers).
/// Returns a standard modular crypt-formatted hash string (e.g., `$2a$12$...` or `$2b$12$...`).
///
/// Throws [ArgumentError] if the [password] is empty or [cost] is out of range (`4`..`31`).
/// Throws [PasswordHashException] if hashing fails due to an unexpected cryptographic error.
///
/// Example:
/// ```dart
/// // Hash password with default cost (12)
/// final hash = hashPassword('user-submitted-password');
///
/// // Hash password with custom work factor
/// final strongHash = hashPassword('user-submitted-password', cost: 14);
/// ```
String hashPassword(String password, {int cost = 12}) {
  if (password.isEmpty) {
    throw ArgumentError.value(password, 'password', 'Password cannot be empty');
  }
  if (cost < 4 || cost > 31) {
    throw ArgumentError.value(
      cost,
      'cost',
      'BCrypt cost must be between 4 and 31',
    );
  }

  try {
    final salt = BCrypt.gensalt(logRounds: cost);
    return BCrypt.hashpw(password, salt);
  } catch (e, st) {
    throw PasswordHashException('Failed to hash password: $e', st);
  }
}

/// Verifies a plaintext [password] against a modular crypt-formatted BCrypt [hash].
///
/// Returns `true` if the password matches the hash, `false` if it does not or if
/// the hash format is malformed or invalid. Fails closed on any parsing or comparison errors.
///
/// Example:
/// ```dart
/// final isValid = verifyPassword(enteredPassword, storedUserHash);
/// if (isValid) {
///   // Authentication succeeded
/// } else {
///   // Invalid credentials
/// }
/// ```
bool verifyPassword(String password, String hash) {
  if (password.isEmpty || hash.isEmpty) {
    return false;
  }

  try {
    return BCrypt.checkpw(password, hash);
  } catch (_) {
    // Malformed hash or invalid format - fail closed
    return false;
  }
}

/// Executes a dummy password verification cycle using a cost-matched hash.
///
/// Use this when a user lookup by username or email returns no record. By executing
/// the same cryptographic workload as a real verification, response time remains
/// uniform, neutralizing user enumeration and timing side-channel attacks.
///
/// [cost] must match the cost used for real password hashes. The generated
/// dummy hash is cached per cost, so each configured workload is performed at
/// the same BCrypt work factor without regenerating a salt on every request.
/// Always returns `false`.
///
/// Example:
/// ```dart
/// final user = await userDb.findByEmail(email);
/// final bool passwordMatches;
/// if (user != null) {
///   passwordMatches = verifyPassword(candidatePassword, user.passwordHash);
/// } else {
///   // Equalize computation time so attackers cannot differentiate valid vs invalid users
///   dummyVerifyPassword(candidatePassword);
///   passwordMatches = false;
/// }
/// ```
bool dummyVerifyPassword(String candidatePassword, {int cost = 12}) {
  if (cost < 4 || cost > 31) return false;
  try {
    final dummyHash = _dummyBcryptHashes.putIfAbsent(
      cost,
      () => BCrypt.hashpw(
        'bloom-dummy-password',
        BCrypt.gensalt(logRounds: cost),
      ),
    );
    return BCrypt.checkpw(candidatePassword, dummyHash);
  } catch (_) {
    return false;
  }
}
