// lib/bloom_auth_server.dart
/// Server-side authentication primitives and middleware for Bloom backend servers.
///
/// Provides OpenBSD BCrypt password hashing with constant-time dummy verification,
/// cryptographically signed Bearer JWT session token issuance, sliding-window rate
/// limiting and account lockout protection, single-purpose password reset tokens,
/// and request authentication middleware.
///
/// Example usage:
/// ```dart
/// // 1. Hash and verify passwords with BCrypt
/// final hash = hashPassword('my-secret-password', cost: 12);
/// final isValid = verifyPassword('my-secret-password', hash);
///
/// // 2. Issue and verify JWT session tokens
/// final token = issueSessionToken(
///   userId: 'usr_123',
///   email: 'user@example.com',
///   roles: ['admin'],
/// );
/// final claims = verifySessionToken(token);
/// print(claims.userId); // 'usr_123'
/// ```
library bloom_auth_server;

export 'src/password.dart';
export 'src/session_token.dart';
export 'src/rate_limit.dart';
export 'src/password_reset.dart';
export 'src/middleware.dart';

