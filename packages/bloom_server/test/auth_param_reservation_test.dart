// test/auth_param_reservation_test.dart
// #21: route path params must not clobber verified auth_user_id.
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

class _VerifiedAuthMiddleware implements BloomMiddleware {
  const _VerifiedAuthMiddleware();
  @override
  Future<BloomResponse?> handle(
      BloomRequest request, BloomNextFunction next) async {
    request.params['auth_user_id'] = 'verified_user';
    request.params['auth_roles'] = 'admin';
    return next();
  }
}

void main() {
  group('auth_* path-param reservation (#21)', () {
    test('colliding route param cannot downgrade verified identity',
        () async {
      final router = BloomApiRouter();
      router.use(const _VerifiedAuthMiddleware());
      router.get('/users/:auth_user_id', (req) async {
        return BloomResponse.json({
          'auth_user_id': req.params['auth_user_id'],
          'auth_roles': req.params['auth_roles'],
        });
      });

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/users/attacker_controlled'),
      );
      final res = await router.handle(req);
      expect(res.statusCode, 200);
      final body = res.bodyJson as Map<String, dynamic>;
      expect(body['auth_user_id'], 'verified_user');
      expect(body['auth_roles'], 'admin');
    });

    test('non-auth params still bind normally', () async {
      final router = BloomApiRouter();
      router.use(const _VerifiedAuthMiddleware());
      router.get('/orgs/:orgId/users/:userId', (req) async {
        return BloomResponse.json({
          'orgId': req.params['orgId'],
          'userId': req.params['userId'],
          'auth_user_id': req.params['auth_user_id'],
        });
      });

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/orgs/o1/users/u2'),
      );
      final res = await router.handle(req);
      expect(res.statusCode, 200);
      final body = res.bodyJson as Map<String, dynamic>;
      expect(body['orgId'], 'o1');
      expect(body['userId'], 'u2');
      expect(body['auth_user_id'], 'verified_user');
    });
  });
}
