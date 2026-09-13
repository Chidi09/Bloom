import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorBoundary', () {
    test('renders child when no error occurs in SSR', () {
      final app = ErrorBoundary(
        builder: () => P(text: 'Healthy Content'),
        fallback: (err, stack) => P(text: 'Error caught: $err'),
      );
      final html = renderToHtml(app);
      expect(html,
          '<!--bloom:error-boundary--><p>Healthy Content</p><!--/bloom:error-boundary-->');
    });

    test('renders fallback when builder throws during SSR', () {
      final app = ErrorBoundary(
        builder: () => throw Exception('Render failure'),
        fallback: (err, stack) => Div(className: 'error', text: 'Caught: $err'),
      );
      final html = renderToHtml(app);
      expect(html,
          '<!--bloom:error-boundary--><div class="error">Caught: Exception: Render failure</div><!--/bloom:error-boundary-->');
    });
  });
}
