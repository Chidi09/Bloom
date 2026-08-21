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

    test('fakeKeyDown carries key and code', () {
      final e = BloomEvent.fakeKeyDown('Enter', code: 'Enter');
      expect(e.type, 'keydown');
      expect(e.key, 'Enter');
      expect(e.code, 'Enter');
    });

    test('fakeMouseMove carries clientX/Y', () {
      final e = BloomEvent.fakeMouseMove(100.0, 200.0);
      expect(e.type, 'mousemove');
      expect(e.clientX, 100.0);
      expect(e.clientY, 200.0);
    });

    test('modifier keys default false', () {
      final e = BloomEvent.fakeClick();
      expect(e.shiftKey, isFalse);
      expect(e.ctrlKey, isFalse);
      expect(e.altKey, isFalse);
      expect(e.metaKey, isFalse);
    });

    test('files field carries filename list', () {
      final e = BloomEvent(type: 'change', files: ['photo.jpg', 'doc.pdf']);
      expect(e.files, ['photo.jpg', 'doc.pdf']);
    });
  });
}
