import 'dart:async';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    BloomData.clear();
    BloomData.sharedPublicScope.clear();
  });

  tearDown(() {
    BloomData.clear();
    // sharedPublicScope may hold public fixtures; clear between tests.
    try {
      BloomData.sharedPublicScope.clear();
    } catch (_) {}
  });

  group('SSR request isolation (#31)', () {
    test('identical private keys do not collide across concurrent requests',
        () async {
      Future<String?> requestA() => BloomData.withRequestScope((scope) async {
            BloomData.setQueryData<String>(['user', 'current'], (_) => 'alice-A');
            // Overlap with B.
            await Future<void>.delayed(const Duration(milliseconds: 20));
            final seen = BloomData.getQueryData<String>(['user', 'current']);
            final dehydrated = BloomData.dehydrate();
            return '$seen|${(dehydrated['queries'] as List).length}';
          });

      Future<String?> requestB() => BloomData.withRequestScope((scope) async {
            BloomData.setQueryData<String>(['user', 'current'], (_) => 'bob-B');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            final seen = BloomData.getQueryData<String>(['user', 'current']);
            final dehydrated = BloomData.dehydrate();
            return '$seen|${(dehydrated['queries'] as List).length}';
          });

      final results = await Future.wait([requestA(), requestB()]);
      expect(results[0], startsWith('alice-A|'));
      expect(results[1], startsWith('bob-B|'));
      // Each dehydration snapshot holds exactly its own entry.
      expect(results[0], endsWith('|1'));
      expect(results[1], endsWith('|1'));
    });

    test('distinct private keys stay out of other responses dehydration',
        () async {
      final dehydratedA = await BloomData.withRequestScope((scope) async {
        BloomData.setQueryData<String>(['private', 'a'], (_) => 'secret-A');
        await Future<void>.delayed(const Duration(milliseconds: 15));
        return BloomData.dehydrate();
      });
      final dehydratedB = await BloomData.withRequestScope((scope) async {
        BloomData.setQueryData<String>(['private', 'b'], (_) => 'secret-B');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return BloomData.dehydrate();
      });

      final jsonA = dehydratedA['queries'] as List;
      final jsonB = dehydratedB['queries'] as List;
      expect(jsonA, hasLength(1));
      expect(jsonB, hasLength(1));
      expect(jsonA.first['key'], ['private', 'a']);
      expect(jsonB.first['key'], ['private', 'b']);
    });

    test('overlapping async deduplication is scoped, not shared', () async {
      var fetchCount = 0;
      Future<String> fetcher() async {
        final n = ++fetchCount;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'value-$n';
      }

      Future<String> scopedFetch(String marker) =>
          BloomData.withRequestScope((scope) async {
            // Two concurrent deduplicate calls *within* the same request scope
            // must collapse to one fetch.
            final f1 = BloomData.deduplicate<String>(['items'], fetcher);
            final f2 = BloomData.deduplicate<String>(['items'], fetcher);
            final results = await Future.wait([f1, f2]);
            expect(results[0], results[1]);
            return results[0];
          });

      final results = await Future.wait([scopedFetch('A'), scopedFetch('B')]);
      // Each request scope fetched independently (2 total), but intra-scope
      // duplicates collapsed (would be 4 if no dedup at all).
      expect(fetchCount, 2);
      // The two scopes resolved independently; values differ because each
      // scope ran its own fetcher invocation.
      expect(results[0], isNot(results[1]));
    });

    test('subsequent requests start clean after cleanup', () async {
      await BloomData.withRequestScope((scope) async {
        BloomData.setQueryData<String>(['session'], (_) => 'first');
        expect(BloomData.getQueryData<String>(['session']), 'first');
      });

      // Second request must not see the first request's private entry.
      await BloomData.withRequestScope((scope) async {
        expect(BloomData.getQueryData<String>(['session']), isNull);
        expect(BloomData.dehydrate()['queries'], isEmpty);
        BloomData.setQueryData<String>(['session'], (_) => 'second');
      });

      // Browser/global scope was never polluted by the request scopes.
      expect(BloomData.getQueryData<String>(['session']), isNull);
    });

    test('disposed scope rejects further use', () async {
      final scope = BloomData.createScope(debugLabel: 'test');
      BloomData.runWithScope(scope, () {
        BloomData.setQueryData<String>(['k'], (_) => 'v');
      });
      scope.dispose();
      expect(scope.isDisposed, isTrue);
      expect(() => scope.getQueryData<String>(['k']), throwsStateError);
      expect(() => scope.setQueryData<String>(['k'], (_) => 'x'),
          throwsStateError);
    });

    test('invalidations do not cross request boundaries', () async {
      final scopeA = BloomData.createScope(debugLabel: 'A');
      final scopeB = BloomData.createScope(debugLabel: 'B');
      try {
        BloomData.runWithScope(scopeA, () {
          BloomData.setQueryData<String>(['tasks'], (_) => 'a-data');
        });
        BloomData.runWithScope(scopeB, () {
          BloomData.setQueryData<String>(['tasks'], (_) => 'b-data');
        });

        var aInvalidated = 0;
        var bInvalidated = 0;
        final subA = BloomData.runWithScope(
            scopeA, () => BloomData.onInvalidated(['tasks']).listen((_) {
                  aInvalidated++;
                }));
        final subB = BloomData.runWithScope(
            scopeB, () => BloomData.onInvalidated(['tasks']).listen((_) {
                  bInvalidated++;
                }));
        try {
          BloomData.runWithScope(
              scopeA, () => BloomData.invalidateQueries(['tasks']));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(aInvalidated, 1);
          expect(bInvalidated, 0);
        } finally {
          await subA.cancel();
          await subB.cancel();
        }
      } finally {
        scopeA.dispose();
        scopeB.dispose();
      }
    });

    test('runSsrRequest covers prime → render → dehydrate pipeline', () async {
      final output = await runSsrRequest((scope) async {
        BloomData.setQueryData<String>(['user', 'current'], (_) => 'Ada');
        final html = renderToHtml(Div(text: 'hello'));
        final state = BloomData.dehydrate();
        final tag = BloomData.dehydrateToScriptTag(state: state);
        return '$html::$tag';
      });
      expect(output, contains('hello'));
      expect(output, contains('Ada'));
      expect(output, contains('__BLOOM_DATA__'));
    });

    test('withRequestScope disposes on error and propagates', () async {
      BloomQueryScope? captured;
      await expectLater(
        BloomData.withRequestScope((scope) async {
          captured = scope;
          BloomData.setQueryData<String>(['k'], (_) => 'v');
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(captured?.isDisposed, isTrue);
    });

    test('streaming scope survives until done and then disposes', () async {
      BloomQueryScope? captured;
      final stream = runSsrRequestStream((scope) {
        captured = scope;
        BloomData.setQueryData<String>(['stream', 'key'], (_) => 's-data');
        return renderToStreamWithSuspenseInScope(
          Suspense<String>(
            resource: () => Future.delayed(
                const Duration(milliseconds: 10), () => 'resolved'),
            builder: (data) => Div(text: data),
            fallback: Div(text: 'loading'),
          ),
          scope,
        );
      });
      final joined = await stream.join();
      expect(joined, contains('loading'));
      expect(joined, contains('resolved'));
      // Scope was owned by runSsrRequestStream and disposed onDone.
      expect(captured?.isDisposed, isTrue);
    });

    test('streaming cancellation disposes the owned scope', () async {
      BloomQueryScope? captured;
      final stream = runSsrRequestStream((scope) {
        captured = scope;
        return renderToStreamWithSuspenseInScope(
          Suspense<String>(
            resource: () => Future.delayed(
                const Duration(milliseconds: 100), () => 'late'),
            builder: (data) => Div(text: data),
            fallback: Div(text: 'loading'),
          ),
          scope,
        );
      });
      final sub = stream.listen((_) {});
      // Cancel before the late resource resolves.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(captured?.isDisposed, isTrue);
    });

    test('explicit shared public caching is opt-in via sharedPublicScope',
        () async {
      BloomData.runWithScope(BloomData.sharedPublicScope, () {
        BloomData.setQueryData<String>(['public', 'config'], (_) => 'v1');
      });

      // Private request scopes do not see it unless they explicitly adopt it.
      await BloomData.withRequestScope((scope) async {
        expect(BloomData.getQueryData<String>(['public', 'config']), isNull);
        scope.adoptEntryFrom(
            BloomData.sharedPublicScope, ['public', 'config']);
        expect(
            BloomData.getQueryData<String>(['public', 'config']), 'v1');
        // Private writes never flow back to the shared scope.
        BloomData.setQueryData<String>(['user', 'current'], (_) => 'private');
      });

      BloomData.runWithScope(BloomData.sharedPublicScope, () {
        expect(BloomData.getQueryData<String>(['user', 'current']), isNull);
        expect(
            BloomData.getQueryData<String>(['public', 'config']), 'v1');
      });
    });

    test('BloomQuery instances are request-scoped', () async {
      Future<String?> runQuery(String value) =>
          BloomData.withRequestScope((scope) async {
            final q = query<String>(
              key: ['scoped-query'],
              fetch: () async {
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return value;
              },
            );
            // Wait for fetch to settle.
            await Future<void>.delayed(const Duration(milliseconds: 30));
            final data = q.data.value;
            q.dispose();
            return data;
          });

      final results = await Future.wait([runQuery('A'), runQuery('B')]);
      expect(results, contains('A'));
      expect(results, contains('B'));
      // Order-independent: both values present exactly once.
      expect(results.toSet(), {'A', 'B'});
    });
  });
}
