import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomEvent', () {
    test('fakeClick', () {
      final e = BloomEvent.fakeClick();
      expect(e.type, 'click');
      expect(e.value, isNull);
    });

    test('fakeInput carries value', () {
      final e = BloomEvent.fakeInput('hello');
      expect(e.type, 'input');
      expect(e.value, 'hello');
    });

    test('preventDefault marks flag', () {
      var called = false;
      final e = BloomEvent(type: 'click', preventDefaultFn: () => called = true);
      e.preventDefault();
      expect(e.defaultPrevented, isTrue);
      expect(called, isTrue);
    });

    test('stopPropagation marks flag', () {
      var called = false;
      final e = BloomEvent(type: 'click', stopPropagationFn: () => called = true);
      e.stopPropagation();
      expect(e.propagationStopped, isTrue);
      expect(called, isTrue);
    });

    test('handler receives BloomEvent', () {
      var received = '';
      final el = Button(onClick: (e) => received = e.type) as ElNode;
      el.on!['click']!(BloomEvent.fakeClick());
      expect(received, 'click');
    });
  });
}
