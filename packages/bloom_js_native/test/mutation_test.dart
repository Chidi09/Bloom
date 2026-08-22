import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomMutation', () {
    setUp(() => BloomData.clear());

    test('starts in idle state', () {
      final m = BloomMutation<String, String>(
        mutateFn: (p) async => 'result: $p',
      );
      expect(m.isIdle, isTrue);
      expect(m.data.value, isNull);
      expect(m.error.value, isNull);
    });

    test('mutate() transitions pending -> success', () async {
      final m = BloomMutation<String, String>(
        mutateFn: (p) async => 'hello $p',
      );
      final result = await m.mutate('world');
      expect(result, 'hello world');
      expect(m.isSuccess, isTrue);
      expect(m.data.value, 'hello world');
    });

    test('mutateAsync() returns value on success', () async {
      final m = BloomMutation<int, int>(mutateFn: (p) async => p * 2);
      final result = await m.mutateAsync(5);
      expect(result, 10);
    });

    test('mutate() returns null on failure and sets error state', () async {
      final m = BloomMutation<String, String>(
        mutateFn: (_) async => throw Exception('boom'),
      );
      final result = await m.mutate('x');
      expect(result, isNull);
      expect(m.isError, isTrue);
      expect(m.error.value, isA<Exception>());
    });

    test('mutateAsync() rethrows on failure', () async {
      final m = BloomMutation<String, String>(
        mutateFn: (_) async => throw Exception('kaboom'),
      );
      expect(() => m.mutateAsync('x'), throwsA(isA<Exception>()));
    });

    test('reset() returns to idle state', () async {
      final m = BloomMutation<String, String>(
        mutateFn: (p) async => p,
      );
      await m.mutate('hi');
      m.reset();
      expect(m.isIdle, isTrue);
      expect(m.data.value, isNull);
    });

    test('onSuccess callback is called with result', () async {
      String? captured;
      final m = BloomMutation<String, String>(
        mutateFn: (p) async => 'ok $p',
        onSuccess: (data, params, ctx) async {
          captured = data;
        },
      );
      await m.mutateAsync('test');
      expect(captured, 'ok test');
    });

    test('onError callback is called on failure', () async {
      Object? captured;
      final m = BloomMutation<String, String>(
        mutateFn: (_) async => throw Exception('fail'),
        onError: (err, params, ctx) async {
          captured = err;
        },
      );
      await m.mutate('x');
      expect(captured, isA<Exception>());
    });

    test('onSettled callback is called on both success and error', () async {
      final settled = <String>[];
      final successM = BloomMutation<String, String>(
        mutateFn: (p) async => p,
        onSettled: (data, err, params, ctx) async {
          settled.add(err == null ? 'success' : 'error');
        },
      );
      await successM.mutate('x');

      final errorM = BloomMutation<String, String>(
        mutateFn: (_) async => throw Exception('oops'),
        onSettled: (data, err, params, ctx) async {
          settled.add(err == null ? 'success' : 'error');
        },
      );
      await errorM.mutate('x');
      expect(settled, ['success', 'error']);
    });

    test('invalidateKeys triggers cache invalidation on success', () async {
      BloomData.setQueryData<String>(['tasks'], (_) => 'old');
      bool invalidated = false;
      final sub = BloomData.onInvalidated(['tasks']).listen((_) {
        invalidated = true;
      });

      final m = BloomMutation<String, String>(
        mutateFn: (p) async => p,
        invalidateKeys: [
          ['tasks']
        ],
      );
      await m.mutateAsync('new');
      await Future.microtask(() {});
      expect(invalidated, isTrue);
      await sub.cancel();
    });

    test('optimistic update is rolled back on error', () async {
      BloomData.setQueryData<String>(['key'], (_) => 'original');

      final m = BloomMutation<String, String>(
        mutateFn: (_) async => throw Exception('fail'),
        optimisticKey: ['key'],
        optimisticData: (params, old) => 'optimistic',
      );

      await m.mutate('x');

      // After error, snapshot must be rolled back
      expect(BloomData.getQueryData<String>(['key']), 'original');
      expect(m.isError, isTrue);
    });
  });
}
