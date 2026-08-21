import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

class AuthGuard extends BloomRouteGuard {
  final bool isAuthenticated;
  const AuthGuard(this.isAuthenticated);

  @override
  FutureOr<GuardResult> canActivate(String location, Map<String, String> params) {
    if (!isAuthenticated) return GuardResult.redirect('/login');
    return GuardResult.allow();
  }
}

void main() {
  group('BloomRouteGuard', () {
    test('allows navigation when guard permits', () async {
      final router = BloomRouter([
        BloomRoute('/dashboard', (_) => const Span.raw(text: 'Dashboard'), guards: [const AuthGuard(true)]),
        BloomRoute('/login', (_) => const Span.raw(text: 'Login')),
      ]);
      final match = router.match('/dashboard');
      expect(match, isNotNull);
      final allowed = await router.evaluateGuards(match!.route, '/dashboard', match.params);
      expect(allowed.isAllowed, isTrue);
    });

    test('redirects navigation when guard denies', () async {
      final router = BloomRouter([
        BloomRoute('/dashboard', (_) => const Span.raw(text: 'Dashboard'), guards: [const AuthGuard(false)]),
        BloomRoute('/login', (_) => const Span.raw(text: 'Login')),
      ]);
      final match = router.match('/dashboard');
      expect(match, isNotNull);
      final result = await router.evaluateGuards(match!.route, '/dashboard', match.params);
      expect(result.isAllowed, isFalse);
      expect(result.redirectPath, '/login');
    });
  });
}
