# bloom_auth_server

Server-side authentication primitives and middleware for Bloom backend servers and full-stack Dart applications.

Modeled after the battle-tested design of `djangors-auth`, `bloom_auth_server` provides the server-side counterpart to `bloom_framework`'s client-side `BloomAuth<U>`:

* **Strong Password Hashing**: OpenBSD BCrypt password hashing (`hashPassword`, `verifyPassword`) with constant-time dummy verification (`dummyVerifyPassword`) to defeat user enumeration.
* **Cryptographically Signed Session Tokens**: Bearer JWT tokens (`issueSessionToken`, `verifySessionToken`) signed with HMAC-SHA256 and domain-separated with `token_type: 'session'`.
* **Sliding-Window Rate Limiting & Account Lockout**: In-memory sliding-window throttling (`InMemoryRateLimiter`) and consecutive-failure lockout (`InMemoryLockoutManager`, `AuthRateLimiter`) with fail-closed security semantics.
* **Single-Purpose Password Reset Workflows**: Time-limited, signed password reset tokens (`generatePasswordResetToken`, `verifyPasswordResetToken`) cryptographically bound to the user's password hash so any password change invalidates all outstanding reset tokens instantly.
* **Server Verification Middleware**: Drop-in `BloomAuthMiddleware` for `BloomApiRouter` supporting token extraction, expiration checks, role enforcement, and request extensions (`request.auth`, `request.authUserId`).

---

## Installation

Add `bloom_auth_server` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_framework:
    path: ../bloom_framework
  bloom_auth_server:
    path: ../bloom_auth_server
```

---

## Configuration

Secrets are loaded dynamically through `BloomEnv` rather than hardcoded literals. Set your environment variables in `.env` or system environment:

```env
BLOOM_AUTH_SECRET=your-secure-random-32-byte-secret-key-here
```

Initialize `BloomEnv` on server boot:

```dart
import 'package:bloom_framework/bloom_framework.dart';

void main() {
  BloomEnv.loadContent('BLOOM_AUTH_SECRET=your-secure-random-32-byte-secret-key-here');
}
```

---

## Full Worked Example

The following standalone example demonstrates:
1. User registration with BCrypt password hashing.
2. User authentication with rate limiting, account lockout protection, and JWT session token issuance.
3. Password reset request and confirmation with hash-bound token invalidation.
4. Protected API endpoints guarded by `BloomAuthMiddleware`.
5. Seamless consumption by the client-side `BloomAuth<U>` session manager.

```dart
import 'dart:io';
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_auth_server/bloom_auth_server.dart';

/// In-memory user database model for this example.
/// In production, replace with `bloom_db` or your preferred database.
class UserRecord {
  final String id;
  final String email;
  String passwordHash; // Never store plaintext passwords
  final List<String> roles;

  UserRecord({
    required this.id,
    required this.email,
    required this.passwordHash,
    this.roles = const ['user'],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'roles': roles,
  };
}

final Map<String, UserRecord> usersByEmail = {};
final Map<String, UserRecord> usersById = {};

// Unified rate limiter: 5 attempts per 15min window, 1 hour lockout after 5 consecutive failures
final authLimiter = AuthRateLimiter(
  maxAttempts: 5,
  window: const Duration(minutes: 15),
  lockoutDuration: const Duration(hours: 1),
);

// ---------------------------------------------------------------------------
// Route Handlers
// ---------------------------------------------------------------------------

/// POST /api/auth/signup - Hashes password with BCrypt and creates the user account.
Future<BloomResponse> handleSignup(BloomRequest req) async {
  final body = req.bodyJson;
  final email = body is Map ? body['email']?.toString().trim().toLowerCase() : null;
  final password = body is Map ? body['password']?.toString() : null;

  if (email == null || email.isEmpty || password == null || password.length < 8) {
    return BloomResponse.error('Valid email and password (min 8 chars) required', statusCode: 400);
  }

  if (usersByEmail.containsKey(email)) {
    return BloomResponse.error('An account with this email already exists', statusCode: 409);
  }

  // Hash password using BCrypt with cost factor 12
  final hashedPassword = hashPassword(password, cost: 12);
  final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';

  final user = UserRecord(
    id: userId,
    email: email,
    passwordHash: hashedPassword,
    roles: ['user'],
  );

  usersByEmail[email] = user;
  usersById[userId] = user;

  // Issue session token for immediate login upon signup
  final token = issueSessionToken(
    userId: user.id,
    email: user.email,
    roles: user.roles,
    ttl: const Duration(days: 7),
  );

  return BloomResponse.json({
    'token': token,
    'user': user.toJson(),
  }, statusCode: 201);
}

/// POST /api/auth/login - Validates rate limits, verifies password, and issues session token.
Future<BloomResponse> handleLogin(BloomRequest req) async {
  final body = req.bodyJson;
  final email = body is Map ? body['email']?.toString().trim().toLowerCase() : null;
  final password = body is Map ? body['password']?.toString() : null;

  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    return BloomResponse.error('Email and password are required', statusCode: 400);
  }

  // 1. Verify rate limiting and lockout state (fails closed on limit reached)
  try {
    authLimiter.verifyAllowed(email);
  } on AccountLockedException catch (e) {
    return BloomResponse.json({
      'error': 'Account is temporarily locked due to too many failed attempts.',
      'retryAfterSeconds': e.retryAfterSeconds,
    }, statusCode: 429);
  } on RateLimitException catch (e) {
    return BloomResponse.json({
      'error': 'Too many login attempts. Please try again later.',
      'retryAfterSeconds': e.retryAfterSeconds,
    }, statusCode: 429);
  }

  // 2. Lookup user and verify password
  final user = usersByEmail[email];

  if (user == null) {
    // Execute dummy verification to preserve uniform timing and prevent user enumeration
    dummyVerifyPassword(password);
    authLimiter.recordFailure(email);
    return BloomResponse.unauthorized('Invalid email or password');
  }

  final isValid = verifyPassword(password, user.passwordHash);
  if (!isValid) {
    authLimiter.recordFailure(email);
    return BloomResponse.unauthorized('Invalid email or password');
  }

  // 3. Successful authentication clears failure streaks
  authLimiter.recordSuccess(email);

  // 4. Issue cryptographically signed session JWT
  final token = issueSessionToken(
    userId: user.id,
    email: user.email,
    roles: user.roles,
    ttl: const Duration(days: 7),
  );

  return BloomResponse.json({
    'token': token,
    'user': user.toJson(),
  });
}

/// POST /api/auth/reset-password/request - Generates a signed, single-purpose reset token.
Future<BloomResponse> handleRequestPasswordReset(BloomRequest req) async {
  final body = req.bodyJson;
  final email = body is Map ? body['email']?.toString().trim().toLowerCase() : null;

  if (email == null || email.isEmpty) {
    return BloomResponse.error('Email is required', statusCode: 400);
  }

  final user = usersByEmail[email];
  if (user != null) {
    // Generate reset token bound to user's current password hash
    final resetToken = generatePasswordResetToken(
      userId: user.id,
      currentPasswordHash: user.passwordHash,
      ttl: const Duration(hours: 1),
    );

    // In a real app, send `resetToken` via email service (e.g. `bloom_mail`):
    // await mailer.sendPasswordResetEmail(user.email, resetToken);
  }

  // Always return 200 to prevent email enumeration
  return BloomResponse.json({
    'message': 'If an account exists with this email, a password reset link has been sent.',
  });
}

/// POST /api/auth/reset-password/confirm - Verifies reset token and updates password.
Future<BloomResponse> handleConfirmPasswordReset(BloomRequest req) async {
  final body = req.bodyJson;
  final token = body is Map ? body['token']?.toString() : null;
  final newPassword = body is Map ? body['newPassword']?.toString() : null;

  if (token == null || token.isEmpty || newPassword == null || newPassword.length < 8) {
    return BloomResponse.error('Valid token and new password (min 8 chars) required', statusCode: 400);
  }

  final payload = parsePasswordResetToken(token);
  if (payload == null || payload.isExpired) {
    return BloomResponse.error('Invalid or expired reset token', statusCode: 400);
  }

  final user = usersById[payload.userId];
  if (user == null) {
    return BloomResponse.error('Invalid or expired reset token', statusCode: 400);
  }

  // Verify HMAC signature against current hash
  final isValid = verifyPasswordResetToken(
    token: token,
    userId: user.id,
    currentPasswordHash: user.passwordHash,
  );

  if (!isValid) {
    return BloomResponse.error('Invalid or expired reset token', statusCode: 400);
  }

  // Update password hash. This automatically invalidates any existing reset tokens!
  user.passwordHash = hashPassword(newPassword, cost: 12);

  return BloomResponse.json({
    'message': 'Password has been successfully updated.',
  });
}

/// GET /api/profile - Protected route requiring a valid session token.
Future<BloomResponse> handleGetProfile(BloomRequest req) async {
  // `req.auth` and `req.authUserId` are populated by BloomAuthMiddleware
  final userId = req.authUserId!;
  final user = usersById[userId];

  if (user == null) {
    return BloomResponse.notFound('User not found');
  }

  return BloomResponse.json({
    'user': user.toJson(),
    'claims': req.auth?.toMap(),
  });
}

// ---------------------------------------------------------------------------
// Server Entrypoint
// ---------------------------------------------------------------------------

Future<void> main() async {
  // Set secret in environment
  BloomEnv.loadMap({
    'BLOOM_AUTH_SECRET': 'super-secret-signing-key-32-chars-minimum-prod',
  });

  final router = BloomApiRouter();

  // Public authentication routes
  router.post('/api/auth/signup', handleSignup);
  router.post('/api/auth/login', handleLogin);
  router.post('/api/auth/reset-password/request', handleRequestPasswordReset);
  router.post('/api/auth/reset-password/confirm', handleConfirmPasswordReset);

  // Protected routes guarded by BloomAuthMiddleware
  router.get(
    '/api/profile',
    handleGetProfile,
    middlewares: [const BloomAuthMiddleware()],
  );

  // Admin-only route example
  router.get(
    '/api/admin/stats',
    (req) => BloomResponse.json({'activeUsers': usersById.length}),
    middlewares: [BloomAuthMiddleware.requireRole('admin')],
  );

  final server = await router.serve(port: 8080);
  stdout.writeln('Auth server listening on http://${server.address.address}:${server.port}');
}
```

---

## Client Integration with `BloomAuth<U>`

The response format from `handleLogin` / `handleSignup` (`{ token: "...", user: { ... } }`) matches the client-side `BloomAuth<U>` contract in `bloom_framework`:

```dart
import 'package:bloom_framework/bloom_framework.dart';

final clientAuth = BloomAuth<Map<String, dynamic>>(
  fromJson: (json) => json,
  toJson: (user) => user,
);

// Establish session from server login response
final loginResponse = await http.post(
  Uri.parse('http://localhost:8080/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'email': 'alice@example.com', 'password': 'my-secure-password'}),
);

final data = jsonDecode(loginResponse.body);
await clientAuth.login(data['token'], data['user']);

// Check authentication state reactively
print('Is authenticated: ${clientAuth.isAuthenticated.value}');
print('Current bearer token: ${clientAuth.token.value}');
```

---

## Security Architecture & Design Decisions

### 1. Password Hashing (`package:bcrypt`)
- Algorithm: OpenBSD BCrypt (PHC / modular crypt format `$2a$` / `$2b$`).
- Work Factor: Configurable log2 cost (default `12` rounds = 4096 iterations), resistant to GPU and ASIC acceleration.
- User Enumeration Protection: `dummyVerifyPassword` runs standard BCrypt cycles when accounts are missing, maintaining uniform response latency.

### 2. Session Tokens (`package:dart_jsonwebtoken`)
- Standard: RFC 7519 JSON Web Tokens (JWT).
- Signature: HMAC-SHA256 (HS256) with key length validation via `BloomEnv.get('BLOOM_AUTH_SECRET')`.
- Domain Separation: Embedded `token_type: 'session'` claim ensures session tokens cannot be swapped with password reset or API key tokens.

### 3. Account Lockout & Throttling
- Sliding Window: In-memory tracker rejecting rapid automated requests (`maxAttempts: 5`, `window: 15m`).
- Account Lockout: Rejects all requests (even with valid credentials) when consecutive failures reach threshold (`lockoutDuration: 1h`).
- Fail-Closed: Any internal error or ambiguous state denies access rather than allowing unchecked requests.

### 4. Password Reset Tokens
- Format: `rst.<base64(userId)>.<base64(expiry)>.<base64(hmac)>`.
- Dynamic Hash Binding: The HMAC payload binds `userId`, `expiry`, and `passwordHashPrefix`. Changing the password immediately invalidates all outstanding reset tokens without requiring database revocation tables.
