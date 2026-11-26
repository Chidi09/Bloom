import 'dart:async';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Concurrent Transitions', () {
    test('isTransitionPending signal tracks transition execution', () async {
      expect(isTransitionPending.value, isFalse);
      final done = Completer<void>();
      startTransition(() {
        done.complete();
      });
      expect(isTransitionPending.value, isTrue);
      await done.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(isTransitionPending.value, isFalse);
    });

    test('scheduleTransition resolves task and clears pending state',
        () async {
      expect(isTransitionPending.value, isFalse);
      final task = scheduleTransition<int>(() => 42);
      expect(isTransitionPending.value, isTrue);
      final result = await task.future.timeout(const Duration(seconds: 2));
      expect(result, 42);
      await Future<void>.delayed(Duration.zero);
      expect(isTransitionPending.value, isFalse);
    });
  });
}
