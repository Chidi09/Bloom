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

    group('resolveRedirects loop detection (#17)', () {
      BloomRouter loopRouter() => BloomRouter([
            BloomRoute('/a', (_) => const Span.raw(text: 'A'),
                guards: [_RedirectGuard('/b')]),
            BloomRoute('/b', (_) => const Span.raw(text: 'B'),
                guards: [_RedirectGuard('/a')]),
            BloomRoute('/self', (_) => const Span.raw(text: 'Self'),
                guards: [_RedirectGuard('/self')]),
            BloomRoute('/start', (_) => const Span.raw(text: 'Start'),
                guards: [_RedirectGuard('/middle')]),
            BloomRoute('/middle', (_) => const Span.raw(text: 'Middle'),
                guards: [_RedirectGuard('/end')]),
            BloomRoute('/end', (_) => const Span.raw(text: 'End')),
            BloomRoute('/locked', (_) => const Span.raw(text: 'Locked'),
                guards: [_DenyGuard()]),
          ]);

      test('two-route cycle throws with the chain', () async {
        final router = loopRouter();
        expect(
          () => router.resolveRedirects('/a'),
          throwsA(isA<BloomRedirectLoopException>()
              .having((e) => e.chain, 'chain', ['/a', '/b'])
              .having((e) => e.offendingTarget, 'offendingTarget', '/a')),
        );
      });

      test('self-redirect throws', () async {
        final router = loopRouter();
        expect(
          () => router.resolveRedirects('/self'),
          throwsA(isA<BloomRedirectLoopException>()),
        );
      });

      test('acyclic chain resolves to the final location', () async {
        final router = loopRouter();
        final res = await router.resolveRedirects('/start');
        expect(res.location, '/end');
        expect(res.blocked, isFalse);
        expect(res.match, isNotNull);
      });

      test('deny without redirect yields a blocked resolution', () async {
        final router = loopRouter();
        final res = await router.resolveRedirects('/locked');
        expect(res.blocked, isTrue);
        expect(res.location, '/locked');
      });

      test('hop budget is enforced and configurable', () async {
        BloomRouter chainRouter(int hops) {
          final routes = <BloomRoute>[];
          for (var i = 0; i <= hops; i++) {
            final from = '/n$i';
            final to = '/n${i + 1}';
            routes.add(BloomRoute(from, (_) => const Span.raw(text: 'n'),
                guards: [_RedirectGuard(to)]));
          }
          routes.add(BloomRoute('/n${hops + 1}',
              (_) => const Span.raw(text: 'last')));
          return BloomRouter(routes);
        }

        // 12-hop chain exceeds the default budget of 10.
        expect(
          () => chainRouter(12).resolveRedirects('/n0'),
          throwsA(isA<BloomRedirectLoopException>()),
        );
        // A raised budget lets the same chain through.
        final res = await chainRouter(12)
            .resolveRedirects('/n0', maxRedirects: 20);
        expect(res.location, '/n13');
      });
    });
  });
}

class _RedirectGuard extends BloomRouteGuard {
  final String target;
  const _RedirectGuard(this.target);

  @override
  FutureOr<GuardResult> canActivate(
          String location, Map<String, String> params) =>
      GuardResult.redirect(target);
}

class _DenyGuard extends BloomRouteGuard {
  const _DenyGuard();

  @override
  FutureOr<GuardResult> canActivate(
          String location, Map<String, String> params) =>
      GuardResult.deny();
}
