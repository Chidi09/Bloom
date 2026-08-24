// lib/bloom_auth_server.dart
/// Server-side authentication primitives and middleware for Bloom backend servers.
///
/// Provides production-grade authentication mechanisms for Bloom server applications:
/// - **BCrypt Password Hashing**: OpenBSD BCrypt password hashing via [hashPassword], verification
///   via [verifyPassword], and constant-time dummy verification via [dummyVerifyPassword] to
///   neutralize timing side-channel attacks and user enumeration.
/// - **JWT Bearer Session Tokens**: Signed HMAC-SHA256 session token issuance via [issueSessionToken],
///   verification via [verifySessionToken] and [tryVerifySessionToken], returning structured [BloomAuthClaims].
/// - **Rate Limiting & Lockout**: Sliding-window rate limiting via [InMemoryRateLimiter] and consecutive-failure
///   account lockout via [InMemoryLockoutManager], unified under [AuthRateLimiter].
/// - **Password Reset Tokens**: Signed, time-limited, single-purpose password reset tokens via
///   [generatePasswordResetToken], [parsePasswordResetToken], and [verifyPasswordResetToken] bound
///   to the user's current password hash for automatic revocation upon password change.
/// - **Authentication Middleware**: HTTP request Bearer token parsing and role-based access control
///   via [BloomAuthMiddleware] and convenience accessors via [BloomAuthRequestExtension].
///
/// ### End-to-End Example
/// ```dart
/// import 'package:bloom_auth_server/bloom_auth_server.dart';
/// import 'package:bloom_server/bloom_server.dart';
///
/// // 1. Password Hashing & Verification
/// final hash = hashPassword('super-secret-password', cost: 12);
/// final isCorrect = verifyPassword('super-secret-password', hash);
///
/// // Constant-time dummy verification when user is not found
/// if (!userExists) {
///   dummyVerifyPassword('candidate-password');
/// }
///
/// // 2. Issue & Verify JWT Session Tokens
/// final token = issueSessionToken(
///   userId: 'usr_987',
///   email: 'alex@example.com',
///   roles: ['admin', 'editor'],
///   ttl: const Duration(days: 7),
/// );
/// final claims = verifySessionToken(token);
/// print('Authenticated user: ${claims.userId}, roles: ${claims.roles}');
///
/// // 3. Rate Limiting & Account Lockout
/// final rateLimiter = AuthRateLimiter(maxAttempts: 5, window: Duration(minutes: 15));
/// final status = rateLimiter.verifyAllowed('alex@example.com');
/// if (!status.allowed) {
///   print('Throttled or locked out. Retry in ${status.retryAfterSeconds}s');
/// }
///
/// // 4. Password Reset Token Flow
/// final resetToken = generatePasswordResetToken(
///   userId: 'usr_987',
///   currentPasswordHash: hash,
///   ttl: const Duration(hours: 1),
/// );
/// final isValidReset = verifyPasswordResetToken(
///   token: resetToken,
///   userId: 'usr_987',
///   currentPasswordHash: hash,
/// );
///
/// // 5. Bloom API Server Middleware
/// final router = BloomApiRouter();
/// router.use(BloomAuthMiddleware.requireRole('admin'));
/// router.get('/admin/dashboard', (req) async {
///   final userId = req.authUserId;
///   return BloomResponse.json({'status': 'ok', 'userId': userId});
/// });
/// ```
library;

export 'src/password.dart';
export 'src/session_token.dart';
export 'src/rate_limit.dart';
export 'src/password_reset.dart';
export 'src/middleware.dart';

