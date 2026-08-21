import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Concurrent Transitions', () {
    test('isTransitionPending signal tracks transition execution', () async {
      expect(isTransitionPending.value, isFalse);
      startTransition(() {
        // Deferred state update
      });
      expect(isTransitionPending.value, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(isTransitionPending.value, isFalse);
    });
  });
}
