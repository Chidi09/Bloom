import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

final themeContext = createContext<String>('light');
final countContext = createContext<int>(0);

void main() {
  group('Context API', () {
    test('useContext returns default value when unprovided', () {
      expect(useContext(themeContext), 'light');
      expect(useContext(countContext), 0);
    });

    test('SSR renders child with provided context value', () {
      final app = themeContext.provide(
        'dark',
        Div(children: [
          Live(() => P(text: 'Theme: ${useContext(themeContext)}')),
        ]),
      );
      final html = renderToHtml(app);
      expect(html, '<div><p>Theme: dark</p></div>');
    });

    test('nested context overrides parent value', () {
      final app = themeContext.provide(
        'dark',
        Div(children: [
          Live(() => P(text: 'Outer: ${useContext(themeContext)}')),
          themeContext.provide(
            'midnight',
            Live(() => P(text: 'Inner: ${useContext(themeContext)}')),
          ),
        ]),
      );
      final html = renderToHtml(app);
      expect(html, '<div><p>Outer: dark</p><p>Inner: midnight</p></div>');
    });
  });
}
