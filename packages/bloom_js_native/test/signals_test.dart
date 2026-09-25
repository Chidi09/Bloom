import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('effect keeps normal reactive behavior and cleanup outside browser HMR',
      () {
    final source = signal(0);
    final seenValues = <int>[];

    final cleanup = effect(() => seenValues.add(source.value));
    expect(seenValues, [0]);

    source.value = 1;
    expect(seenValues, [0, 1]);

    cleanup();
    source.value = 2;
    expect(seenValues, [0, 1]);
  });
}
