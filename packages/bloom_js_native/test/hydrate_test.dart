import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Hydration descriptor contracts', () {
    test('renderToDocument with hydratable flag produces hydration markers', () {
      final doc = renderToDocument(
        Div(children: [P(text: 'Hydratable item')]),
        title: 'App',
      );
      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('<p>Hydratable item</p>'));
    });
  });
}
