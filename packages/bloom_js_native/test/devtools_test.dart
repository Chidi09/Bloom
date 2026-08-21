import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('DevTools diagnostics', () {
    test('tracks active regions and sentinels', () {
      expect(BloomJsDevTools.activeRegionCount, isNonNegative);
      expect(BloomJsDevTools.activeSentinelCount, isNonNegative);
    });

    test('registers and notifies diagnostics listeners', () {
      String? lastEvent;
      final unregister = BloomJsDevTools.addListener((evt, data) {
        lastEvent = evt;
      });
      BloomJsDevTools.notify('test:event', {'timestamp': 12345});
      expect(lastEvent, 'test:event');
      unregister();
    });
  });
}
