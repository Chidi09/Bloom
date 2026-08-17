import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_framework/bloom_server.dart';
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

    test('verifyPassword returns false for malformed hash instead of throwing', () {
      expect(verifyPassword('anything', 'not-a-real-hash'), isFalse);
    });

    test('dummyVerifyPassword always returns false without throwing', () {
      expect(dummyVerifyPassword('anything'), isFalse);
    });
  });

  group('Session tokens (JWT)', () {
    setUp(() {
      BloomEnv.loadMap({'BLOOM_AUTH_SECRET': 'test-secret-at-least-32-characters-long'}, overwrite: true);
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

    test('verifySessionToken rejects a token signed with a different secret', () {
      final token = issueSessionToken(userId: '1', secret: 'a-completely-different-secret-value');
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
          throwsA(isA<SessionTokenException>().having((e) => e.isExpired, 'isExpired', isTrue)),
        );
      });
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
}
