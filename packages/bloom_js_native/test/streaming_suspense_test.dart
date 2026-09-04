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

    test('a Suspense nested inside a Div child streams progressively', () async {
      final node = Div(children: [
        Suspense<String>(
          resource: () => Future.value('nested-data'),
          builder: (data) => Div(text: data),
          fallback: Div(text: 'nested-loading'),
        ),
      ]);

      final chunks = await renderToStreamWithSuspense(node).toList();
      expect(chunks.first, contains('nested-loading'));
      expect(chunks.first, isNot(contains('nested-data')));

      final joined = chunks.join();
      expect(joined, contains('nested-data'));
      expect(joined, contains('<script>'));
    });

    test('a Suspense nested two levels deep (Div > Fragment > Div) streams', () async {
      final node = Div(children: [
        Fragment(children: [
          Div(children: [
            Suspense<String>(
              resource: () => Future.value('deep-data'),
              builder: (data) => Div(text: data),
              fallback: Div(text: 'deep-loading'),
            ),
          ]),
        ]),
      ]);

      final chunks = await renderToStreamWithSuspense(node).toList();
      final joined = chunks.join();
      expect(joined, contains('deep-loading'));
      expect(joined, contains('deep-data'));
    });

    test('a Suspense nested inside another Suspense\'s resolved content streams', () async {
      final node = Suspense<String>(
        resource: () => Future.value('outer'),
        builder: (outerData) => Div(children: [
          Suspense<String>(
            resource: () => Future.value('inner'),
            builder: (innerData) => Div(text: '$outerData-$innerData'),
            fallback: Div(text: 'inner-loading'),
          ),
        ]),
        fallback: Div(text: 'outer-loading'),
      );

      final chunks = await renderToStreamWithSuspense(node).toList();
      final joined = chunks.join();
      expect(joined, contains('outer-loading'));
      expect(joined, contains('inner-loading'));
      expect(joined, contains('outer-inner'));
    });

    test('concurrent streams isolate keyframe dedup state (#16)', () async {
      const anim = BloomAnimation(
        name: 'spin',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
          BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
        ],
      );
      BloomNode page(String label, int delayMs) => Div(children: [
            Animated(animation: anim, child: Div(text: '$label-shell')),
            Suspense<String>(
              resource: () => Future.delayed(
                  Duration(milliseconds: delayMs), () => '$label-resolved'),
              builder: (data) =>
                  Animated(animation: anim, child: Div(text: data)),
              fallback: Div(text: 'loading'),
            ),
          ]);

      // Interleaved resolutions: B resolves before A.
      final futureA = renderToStreamWithSuspense(page('A', 30)).join();
      final futureB = renderToStreamWithSuspense(page('B', 10)).join();
      final results = await Future.wait([futureA, futureB]);

      expect(results[0], contains('A-shell'));
      expect(results[0], contains('A-resolved'));
      expect(results[1], contains('B-shell'));
      expect(results[1], contains('B-resolved'));
      // Each stream emits the shared @keyframes block exactly once: shell
      // emits it, the late-resolved patch dedups it within its own stream.
      for (final joined in results) {
        expect('@keyframes spin'.allMatches(joined).length, 1);
      }
    });
  });
}
