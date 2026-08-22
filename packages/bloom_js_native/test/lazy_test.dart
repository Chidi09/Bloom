import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomLazyComponent', () {
    test('load() invokes the loader only once across multiple calls', () async {
      var callCount = 0;
      final component = BloomLazyComponent(() async {
        callCount++;
        return Div(text: 'loaded');
      });

      await component.load();
      await component.load();
      await component.load();

      expect(callCount, 1);
    });

    test('load() resolves to the node returned by the loader', () async {
      final component = BloomLazyComponent(() async => Div(text: 'hello'));
      final node = await component.load();
      expect(node, isA<ElNode>());
    });

    test('reset() causes the next load() to invoke the loader again', () async {
      var callCount = 0;
      final component = BloomLazyComponent(() async {
        callCount++;
        return Div(text: 'loaded');
      });

      await component.load();
      component.reset();
      await component.load();

      expect(callCount, 2);
    });

    test('a failing loader propagates its error to load()', () async {
      final component = BloomLazyComponent(() async => throw StateError('boom'));
      expect(component.load(), throwsA(isA<StateError>()));
    });
  });

  group('lazy()', () {
    test('returns a Suspense node wrapping the loader', () {
      final node = lazy(
        () async => Div(text: 'loaded'),
        fallback: Div(text: 'loading'),
      );
      expect(node, isA<SuspenseNode<BloomNode>>());
    });

    test('does not invoke the loader until the resource is actually read', () async {
      var called = false;
      final node = lazy(
        () async {
          called = true;
          return Div(text: 'loaded');
        },
        fallback: Div(text: 'loading'),
      );
      expect(called, isFalse);
      final suspense = node as SuspenseNode<BloomNode>;
      await suspense.resource();
      expect(called, isTrue);
    });

    test('renders fallback content via SSR while resource is pending', () {
      final node = lazy(
        () => Future<BloomNode>.delayed(
            const Duration(milliseconds: 50), () => Div(text: 'loaded')),
        fallback: Div(text: 'loading-fallback'),
      );
      final html = renderToHtml(node);
      expect(html, contains('loading-fallback'));
    });
  });
}
