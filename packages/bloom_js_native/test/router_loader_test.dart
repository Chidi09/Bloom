import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomRoute loader', () {
    test('a route without a loader builds synchronously via builder', () {
      final router = BloomRouter([
        BloomRoute('/', (params) => Div(text: 'home')),
      ]);
      final match = router.match('/')!;
      final node = match.build();
      expect(node, isA<ElNode>());
    });

    test('a route with a loader returns a Suspense node', () {
      final router = BloomRouter([
        BloomRoute(
          '/user/:id',
          null,
          loader: (params) async => {'name': 'Ada'},
          dataBuilder: (params, data) =>
              Div(text: (data as Map)['name'] as String),
        ),
      ]);
      final match = router.match('/user/42')!;
      final node = match.build();
      expect(node, isA<SuspenseNode<dynamic>>());
    });

    test('loader receives extracted route params', () async {
      Map<String, String>? receivedParams;
      final router = BloomRouter([
        BloomRoute(
          '/user/:id',
          null,
          loader: (params) async {
            receivedParams = params;
            return null;
          },
          dataBuilder: (params, data) => Div(text: 'ok'),
        ),
      ]);
      final match = router.match('/user/42')!;
      final node = match.build() as SuspenseNode<dynamic>;
      await node.resource();
      expect(receivedParams, {'id': '42'});
    });

    test('resolved loader data reaches dataBuilder', () async {
      final router = BloomRouter([
        BloomRoute(
          '/user/:id',
          null,
          loader: (params) async => 'Ada Lovelace',
          dataBuilder: (params, data) => Div(text: data as String),
          loadingFallback: () => Div(text: 'loading'),
        ),
      ]);
      final match = router.match('/user/42')!;
      final node = match.build() as SuspenseNode<dynamic>;
      final data = await node.resource();
      final rendered = node.builder(data);
      expect(renderToHtml(rendered), contains('Ada Lovelace'));
    });

    test('a loader with only builder (no dataBuilder) uses builder, ignoring loaded data', () async {
      final router = BloomRouter([
        BloomRoute(
          '/gate',
          (params) => Div(text: 'gated content'),
          loader: (params) async => 'ignored',
        ),
      ]);
      final match = router.match('/gate')!;
      final node = match.build() as SuspenseNode<dynamic>;
      final data = await node.resource();
      final rendered = node.builder(data);
      expect(renderToHtml(rendered), contains('gated content'));
    });
  });
}
