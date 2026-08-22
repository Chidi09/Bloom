import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('renderToStreamWithSuspense', () {
    test('a plain (non-Suspense) node yields exactly one chunk', () async {
      final chunks = await renderToStreamWithSuspense(Div(text: 'hello')).toList();
      expect(chunks, hasLength(1));
      expect(chunks.first, contains('hello'));
    });

    test('flushes the fallback shell before the resource resolves', () async {
      final node = Suspense<String>(
        resource: () => Future.delayed(
            const Duration(milliseconds: 30), () => 'resolved-data'),
        builder: (data) => Div(text: data),
        fallback: Div(text: 'loading-fallback'),
      );

      final stream = renderToStreamWithSuspense(node);
      final firstChunk = await stream.first;
      expect(firstChunk, contains('loading-fallback'));
      expect(firstChunk, isNot(contains('resolved-data')));
    });

    test('later chunk contains a script replacing the resolved content', () async {
      final node = Suspense<String>(
        resource: () => Future.value('resolved-data'),
        builder: (data) => Div(text: data),
        fallback: Div(text: 'loading'),
      );

      final chunks = await renderToStreamWithSuspense(node).toList();
      expect(chunks.length, greaterThanOrEqualTo(2));
      final joined = chunks.join();
      expect(joined, contains('resolved-data'));
      expect(joined, contains('<script>'));
    });

    test('multiple top-level Suspense boundaries under a Fragment each get a chunk',
        () async {
      final node = Fragment(children: [
        Suspense<String>(
          resource: () => Future.value('first'),
          builder: (data) => Div(text: data),
          fallback: Div(text: 'loading-1'),
        ),
        Suspense<String>(
          resource: () => Future.value('second'),
          builder: (data) => Div(text: data),
          fallback: Div(text: 'loading-2'),
        ),
      ]);

      final chunks = await renderToStreamWithSuspense(node).toList();
      final joined = chunks.join();
      expect(joined, contains('loading-1'));
      expect(joined, contains('loading-2'));
      expect(joined, contains('first'));
      expect(joined, contains('second'));
    });

    test('the sum of all chunks contains the same resolved content as renderToHtml '
        'would after the resource settles', () async {
      final node = Suspense<int>(
        resource: () => Future.value(42),
        builder: (data) => Div(text: 'value: $data'),
        fallback: Div(text: 'loading'),
      );

      final chunks = await renderToStreamWithSuspense(node).toList();
      expect(chunks.join(), contains('value: 42'));
    });

    test('a rejected resource does not hang the stream', () async {
      final node = Suspense<String>(
        resource: () => Future<String>.error(StateError('boom')),
        builder: (data) => Div(text: data),
        fallback: Div(text: 'loading'),
      );

      final chunks = await renderToStreamWithSuspense(node).toList();
      expect(chunks, hasLength(1));
      expect(chunks.first, contains('loading'));
    });
  });
}
