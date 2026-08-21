import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Portal', () {
    test('SSR renders portal template node with data-bloom-portal attribute', () {
      final modal = Portal(
        targetSelector: '#modal-root',
        child: Div(className: 'modal-body', text: 'Modal content'),
      );
      final html = renderToHtml(modal);
      expect(html, contains('data-bloom-portal="#modal-root"'));
      expect(html, contains('<div class="modal-body">Modal content</div>'));
    });
  });
}
