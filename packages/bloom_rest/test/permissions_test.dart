import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:test/test.dart';

BloomRequest _reqWith({String? authUserId, String? authRoles, Map<String, String>? headers}) {
  final req = BloomRequest(
    method: 'GET',
    uri: Uri.parse('http://localhost/x'),
    headers: headers ?? const {},
  );
  if (authUserId != null) req.params['auth_user_id'] = authUserId;
  if (authRoles != null) req.params['auth_roles'] = authRoles;
  return req;
}

void main() {
  group('resolveCurrentUserId', () {
    test('returns the verified auth_user_id param when present', () {
      final req = _reqWith(authUserId: '7');
      expect(resolveCurrentUserId(req), '7');
    });

    test('returns null when auth_user_id is absent', () {
      final req = _reqWith();
      expect(resolveCurrentUserId(req), isNull);
    });

    test('never trusts a raw unverified Authorization header as identity', () {
      // Regression test: this middleware/permission layer must only trust
      // request.params['auth_user_id'], populated by verified auth
      // middleware — never fall back to reading the Authorization header
      // itself, since an unverified bearer token string proves nothing.
      final req = _reqWith(headers: {'authorization': 'Bearer attacker-supplied-token'});
      expect(resolveCurrentUserId(req), isNull);
    });
  });

  group('resolveCurrentUserRoles', () {
    test('parses comma-separated verified roles', () {
      final req = _reqWith(authRoles: 'user,staff');
      expect(resolveCurrentUserRoles(req), ['user', 'staff']);
    });

    test('returns empty list when absent', () {
      expect(resolveCurrentUserRoles(_reqWith()), isEmpty);
    });

    test('never trusts raw client-supplied role headers', () {
      // Regression test: must not fall back to x-user-role / x-is-staff /
      // x-is-superuser headers — those are attacker-controlled.
      final req = _reqWith(headers: {
        'x-user-role': 'admin',
        'x-is-staff': 'true',
        'x-is-superuser': 'true',
      });
      expect(resolveCurrentUserRoles(req), isEmpty);
    });
  });

  group('AllowAny', () {
    test('always permits, authenticated or not', () {
      expect(const AllowAny().hasPermission(_reqWith()), isTrue);
      expect(const AllowAny().hasPermission(_reqWith(authUserId: '1')), isTrue);
    });
  });

  group('IsAuthenticated', () {
    test('denies when unauthenticated', () {
      expect(const IsAuthenticated().hasPermission(_reqWith()), isFalse);
    });

    test('allows when a verified user id is present', () {
      expect(const IsAuthenticated().hasPermission(_reqWith(authUserId: '1')), isTrue);
    });
  });

  group('IsStaff', () {
    test('denies a plain authenticated user', () {
      expect(const IsStaff().hasPermission(_reqWith(authUserId: '1', authRoles: 'user')), isFalse);
    });

    test('allows a user with the staff role', () {
      expect(const IsStaff().hasPermission(_reqWith(authUserId: '1', authRoles: 'staff')), isTrue);
    });

    test('allows an admin (implicitly satisfies staff)', () {
      expect(const IsStaff().hasPermission(_reqWith(authUserId: '1', authRoles: 'admin')), isTrue);
    });
  });

  group('IsSuperuser', () {
    test('denies staff-only users', () {
      expect(const IsSuperuser().hasPermission(_reqWith(authUserId: '1', authRoles: 'staff')), isFalse);
    });

    test('allows superuser role', () {
      expect(const IsSuperuser().hasPermission(_reqWith(authUserId: '1', authRoles: 'superuser')), isTrue);
    });
  });

  group('IsReadOnly', () {
    test('allows GET/HEAD/OPTIONS, denies mutating methods', () {
      for (final m in ['GET', 'HEAD', 'OPTIONS']) {
        final req = BloomRequest(method: m, uri: Uri.parse('http://localhost/x'));
        expect(const IsReadOnly().hasPermission(req), isTrue, reason: m);
      }
      for (final m in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        final req = BloomRequest(method: m, uri: Uri.parse('http://localhost/x'));
        expect(const IsReadOnly().hasPermission(req), isFalse, reason: m);
      }
    });
  });

  group('Combinators', () {
    test('and() requires both to pass', () async {
      final policy = const IsAuthenticated().and(const IsStaff());
      expect(await policy.hasPermission(_reqWith(authUserId: '1', authRoles: 'user')), isFalse);
      expect(await policy.hasPermission(_reqWith(authUserId: '1', authRoles: 'staff')), isTrue);
    });

    test('or() requires at least one to pass', () async {
      final policy = const IsReadOnly().or(const IsStaff());

      final getReq = BloomRequest(method: 'GET', uri: Uri.parse('http://localhost/x'));
      expect(await policy.hasPermission(getReq), isTrue);

      final postFromStaff = BloomRequest(method: 'POST', uri: Uri.parse('http://localhost/x'));
      postFromStaff.params['auth_user_id'] = '1';
      postFromStaff.params['auth_roles'] = 'staff';
      expect(await policy.hasPermission(postFromStaff), isTrue);

      final postFromPlainUser = BloomRequest(method: 'POST', uri: Uri.parse('http://localhost/x'));
      postFromPlainUser.params['auth_user_id'] = '1';
      postFromPlainUser.params['auth_roles'] = 'user';
      expect(await policy.hasPermission(postFromPlainUser), isFalse);
    });

    test('negate() inverts the result', () async {
      final policy = const IsAuthenticated().negate();
      expect(await policy.hasPermission(_reqWith()), isTrue);
      expect(await policy.hasPermission(_reqWith(authUserId: '1')), isFalse);
    });
  });
}
