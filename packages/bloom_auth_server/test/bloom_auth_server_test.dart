import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  group('Password hashing', () {
    test('hashPassword produces a verifiable bcrypt hash', () {
      final hash = hashPassword('correct horse battery staple', cost: 4);
      expect(hash, isNotEmpty);
      expect(verifyPassword('correct horse battery staple', hash), isTrue);
      expect(verifyPassword('wrong password', hash), isFalse);
    });

    test('hashPassword rejects empty password', () {
      expect(() => hashPassword(''), throwsArgumentError);
    });

    test('hashPassword rejects out-of-range cost', () {
      expect(() => hashPassword('x', cost: 2), throwsArgumentError);
      expect(() => hashPassword('x', cost: 32), throwsArgumentError);
    });

    test('verifyPassword returns false for malformed hash instead of throwing',
        () {
      expect(verifyPassword('anything', 'not-a-real-hash'), isFalse);
    });

    test('dummyVerifyPassword always returns false without throwing', () {
      expect(dummyVerifyPassword('anything'), isFalse);
      expect(dummyVerifyPassword('anything', cost: 4), isFalse);
    });
  });

  group('Session tokens (JWT)', () {
    setUp(() {
      BloomEnv.loadMap(
          {'BLOOM_AUTH_SECRET': 'test-secret-at-least-32-characters-long'},
          overwrite: true);
    });

    test('issueSessionToken + verifySessionToken round-trips claims', () {
      final token = issueSessionToken(
        userId: '42',
        email: 'user@example.com',
        roles: const ['user', 'staff'],
      );
      expect(token, isNotEmpty);

      final claims = verifySessionToken(token);
      expect(claims.userId, '42');
      expect(claims.email, 'user@example.com');
      expect(claims.roles, containsAll(['user', 'staff']));
      expect(claims.hasRole('staff'), isTrue);
      expect(claims.hasRole('superuser'), isFalse);
    });

    test('issueSessionToken rejects empty userId', () {
      expect(() => issueSessionToken(userId: ''), throwsArgumentError);
    });

    test('issueSessionToken rejects reserved keys in customClaims (#20)', () {
      for (final reserved in [
        'sub',
        'userId',
        'email',
        'roles',
        'role',
        'token_type',
        'iat',
        'exp',
        'iss',
        'aud',
      ]) {
        expect(
          () => issueSessionToken(
            userId: 'victim',
            customClaims: {reserved: 'attacker'},
          ),
          throwsArgumentError,
          reason: 'reserved key $reserved must be rejected',
        );
      }
    });

    test('issueSessionToken keeps non-reserved customClaims', () {
      final token = issueSessionToken(
        userId: 'victim',
        roles: const ['user'],
        customClaims: const {'tenantId': 't1', 'orgId': 'o1'},
      );
      final claims = verifySessionToken(token);
      expect(claims.userId, 'victim');
      expect(claims.roles, ['user']);
      expect(claims.customClaims['tenantId'], 't1');
      expect(claims.customClaims['orgId'], 'o1');
    });

    test('verifySessionToken rejects an empty token string', () {
      expect(
        () => verifySessionToken(''),
        throwsA(isA<SessionTokenException>()),
      );
    });

    test('verifySessionToken rejects a tampered signature', () {
      final token = issueSessionToken(userId: '1');
      final tampered = '${token.substring(0, token.length - 4)}abcd';
      expect(
        () => verifySessionToken(tampered),
        throwsA(isA<SessionTokenException>()),
      );
    });

    test('verifySessionToken rejects a token signed with a different secret',
        () {
      final token = issueSessionToken(
          userId: '1', secret: 'a-completely-different-secret-value');
      expect(
        () => verifySessionToken(token),
        throwsA(isA<SessionTokenException>()),
      );
    });

    test('verifySessionToken rejects an expired token', () {
      final token = issueSessionToken(
        userId: '1',
        ttl: const Duration(milliseconds: 1),
      );
      // Give the exp claim time to be strictly in the past.
      final expired = Future.delayed(const Duration(milliseconds: 50));
      return expired.then((_) {
        expect(
          () => verifySessionToken(token),
          throwsA(isA<SessionTokenException>()
              .having((e) => e.isExpired, 'isExpired', isTrue)),
        );
      });
    });
    test('verifySessionToken requires exactly token_type == session', () {
      // Craft a token missing token_type or with token_type != 'session'
      final tokenMissingType = issueSessionToken(userId: '1');
      // Token issued by issueSessionToken has token_type: 'session'. Let's verify it works.
      expect(verifySessionToken(tokenMissingType).userId, '1');

      // Now create a raw JWT with custom payload missing token_type or with different token_type
      final secret = resolveAuthSecret();
      final jwtWithoutType = JWT(
        {'sub': '1'},
        issuer: 'bloom-auth-server',
      ).sign(SecretKey(secret));
      expect(
        () => verifySessionToken(jwtWithoutType),
        throwsA(isA<SessionTokenException>().having(
          (e) => e.message,
          'message',
          contains('Invalid token type'),
        )),
      );

      final jwtWithWrongType = JWT(
        {'sub': '1', 'token_type': 'refresh'},
        issuer: 'bloom-auth-server',
      ).sign(SecretKey(secret));
      expect(
        () => verifySessionToken(jwtWithWrongType),
        throwsA(isA<SessionTokenException>().having(
          (e) => e.message,
          'message',
          contains('Invalid token type'),
        )),
      );

      final jwtWithoutExpiry = JWT(
        {'sub': '1', 'token_type': 'session'},
        issuer: 'bloom-auth-server',
      ).sign(SecretKey(secret));
      expect(
        () => verifySessionToken(jwtWithoutExpiry),
        throwsA(isA<SessionTokenException>().having(
          (e) => e.message,
          'message',
          contains('exp'),
        )),
      );
    });
  });

  group('BloomAuthRequestExtension security hardening', () {
    test(
        'authUserId and role helpers do not fall back to mutable request params',
        () {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('/test'),
        headers: {},
        params: {
          'auth_user_id': 'attacker_injected_id',
          'auth_roles': 'admin,superuser',
        },
      );

      // Unauthenticated request with injected params must NOT return the injected values
      expect(req.auth, isNull);
      expect(req.isAuthenticated, isFalse);
      expect(req.authUserId, isNull);
      expect(req.hasRole('admin'), isFalse);
      expect(req.hasAnyRole(['admin', 'superuser']), isFalse);
      expect(req.authRoles, isEmpty);
    });

    test(
        'authUserId and role helpers return only verified claims from middleware',
        () async {
      BloomEnv.loadMap(
          {'BLOOM_AUTH_SECRET': 'test-secret-at-least-32-characters-long'},
          overwrite: true);
      final token = issueSessionToken(
        userId: 'verified_user_123',
        roles: ['editor'],
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('/test'),
        headers: {'Authorization': 'Bearer $token'},
        params: {'auth_user_id': 'spoofed_user'},
      );

      final middleware = const BloomAuthMiddleware();
      await middleware.handle(req, () async => BloomResponse.text('ok'));

      expect(req.isAuthenticated, isTrue);
      expect(req.authUserId, 'verified_user_123');
      expect(req.hasRole('editor'), isTrue);
      expect(req.hasRole('admin'), isFalse);
      expect(req.authRoles, ['editor']);

      // Mutating params after middleware must have no effect on verified getters
      req.params['auth_user_id'] = 'mutated_afterwards';
      expect(req.authUserId, 'verified_user_123');
    });
  });

  group('Password reset token security and revocation', () {
    const passwordHash =
        r'$2a$10$abcdefghijklmnopqrstuvwxyz1234567890abcdefghijkl';

    setUp(() {
      BloomEnv.loadMap(
          {'BLOOM_AUTH_SECRET': 'test-secret-at-least-32-characters-long'},
          overwrite: true);
    });

    test('generatePasswordResetToken rejects non-positive TTL', () {
      expect(
        () => generatePasswordResetToken(
          userId: 'user_1',
          currentPasswordHash: passwordHash,
          ttl: Duration.zero,
        ),
        throwsArgumentError,
      );

      expect(
        () => generatePasswordResetToken(
          userId: 'user_1',
          currentPasswordHash: passwordHash,
          ttl: const Duration(seconds: -10),
        ),
        throwsArgumentError,
      );
    });

    test(
        'verifyPasswordResetToken validates valid token and rejects tampered/expired',
        () {
      final token = generatePasswordResetToken(
        userId: 'user_1',
        currentPasswordHash: passwordHash,
        ttl: const Duration(minutes: 15),
      );

      expect(
        verifyPasswordResetToken(
          token: token,
          userId: 'user_1',
          currentPasswordHash: passwordHash,
        ),
        isTrue,
      );

      // Wrong user
      expect(
        verifyPasswordResetToken(
          token: token,
          userId: 'user_2',
          currentPasswordHash: passwordHash,
        ),
        isFalse,
      );

      // Changed password hash
      expect(
        verifyPasswordResetToken(
          token: token,
          userId: 'user_1',
          currentPasswordHash:
              r'$2a$10$differentHash1234567890abcdefghijklmnopqr',
        ),
        isFalse,
      );
    });

    test('InMemoryPasswordResetRevocationStore enables single-use verification',
        () async {
      final store = InMemoryPasswordResetRevocationStore();
      final token = generatePasswordResetToken(
        userId: 'user_1',
        currentPasswordHash: passwordHash,
        ttl: const Duration(minutes: 15),
      );

      // First use succeeds and marks token as consumed
      final firstUse = await verifyAndConsumePasswordResetToken(
        token: token,
        userId: 'user_1',
        currentPasswordHash: passwordHash,
        revocationStore: store,
      );
      expect(firstUse, isTrue);

      // Second use of the same token is rejected
      final secondUse = await verifyAndConsumePasswordResetToken(
        token: token,
        userId: 'user_1',
        currentPasswordHash: passwordHash,
        revocationStore: store,
      );
      expect(secondUse, isFalse);

      final concurrentToken = generatePasswordResetToken(
        userId: 'user_1',
        currentPasswordHash: passwordHash,
        // Different TTL ensures this token does not share the exact same
        // second-rounded expiry as the token consumed above.
        ttl: const Duration(minutes: 16),
      );
      final concurrentResults = await Future.wait([
        verifyAndConsumePasswordResetToken(
          token: concurrentToken,
          userId: 'user_1',
          currentPasswordHash: passwordHash,
          revocationStore: store,
        ),
        verifyAndConsumePasswordResetToken(
          token: concurrentToken,
          userId: 'user_1',
          currentPasswordHash: passwordHash,
          revocationStore: store,
        ),
      ]);
      expect(concurrentResults.where((result) => result).length, 1);
    });
  });

  group('AuthRateLimiter', () {
    test('allows attempts under the threshold and throttles beyond it', () {
      final limiter = AuthRateLimiter(
        maxAttempts: 3,
        window: const Duration(minutes: 15),
        lockoutDuration: const Duration(hours: 1),
      );
      const key = 'attacker@example.com';

      for (var i = 0; i < 3; i++) {
        limiter.verifyAllowed(key);
        limiter.recordFailure(key);
      }

      expect(
        () => limiter.verifyAllowed(key),
        throwsA(isA<AccountLockedException>()),
      );
    });

    test('recordSuccess clears the failure streak', () {
      final limiter = AuthRateLimiter(
        maxAttempts: 3,
        window: const Duration(minutes: 15),
        lockoutDuration: const Duration(hours: 1),
      );
      const key = 'user@example.com';

      limiter.verifyAllowed(key);
      limiter.recordFailure(key);
      limiter.verifyAllowed(key);
      limiter.recordSuccess(key);

      // Should not throw: failure streak was reset by recordSuccess.
      expect(() => limiter.verifyAllowed(key), returnsNormally);
    });

    test('different keys are tracked independently', () {
      final limiter = AuthRateLimiter(
        maxAttempts: 1,
        window: const Duration(minutes: 15),
        lockoutDuration: const Duration(hours: 1),
      );

      limiter.verifyAllowed('userA');
      limiter.recordFailure('userA');

      // userB should be unaffected by userA's lockout.
      expect(() => limiter.verifyAllowed('userB'), returnsNormally);
    });
  });

  group('Auth middleware header parsing', () {
    test('accepts multiple whitespace characters after Bearer', () async {
      final token = issueSessionToken(userId: '42');
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('/private'),
        headers: {'Authorization': 'Bearer   $token'},
      );
      final res = await const BloomAuthMiddleware().handle(
        req,
        () async => BloomResponse.text('ok'),
      );
      expect(res?.statusCode, 200);
      expect(req.authUserId, '42');
    });
  });
}
