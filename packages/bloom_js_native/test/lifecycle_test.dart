import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('MountNode', () {
    test('Mount wraps child correctly', () {
      final node = Mount(P(text: 'hi'), onMount: () {});
      expect(node.child, isA<ElNode>());
      expect((node.child as ElNode).tag, 'p');
    });

    test('SSR renders child — onMount NOT called', () {
      var called = false;
      final node = Mount(P(text: 'hello'), onMount: () => called = true);
      expect(renderToHtml(node), '<p>hello</p>');
      expect(called, isFalse);
    });
  });

  group('Ref', () {
    test('starts unmounted', () {
      final ref = Ref<Object>();
      expect(ref.isMounted, isFalse);
    });

    test('throws before mount', () {
      final ref = Ref<Object>();
      expect(() => ref.value, throwsStateError);
    });

    test('RefNode wraps child descriptor', () {
      final ref = Ref<Object>();
      final node = RefNode(ref, Div());
      expect((node.child as ElNode).tag, 'div');
    });
  });
}
