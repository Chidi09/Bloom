import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('aria() emits real attribute names and correct boolean serialisation', () {
    final a = aria(label: 'Close', expanded: true, hidden: false);
    expect(a['aria-label'], 'Close');
    expect(a['aria-expanded'], 'true');
    expect(a['aria-hidden'], 'false',
        reason: 'booleans must be "true"/"false", not "1"/"0"');
  });

  test('aria() omits unspecified attributes entirely', () {
    final a = aria(label: 'x');
    expect(a.containsKey('aria-expanded'), isFalse);
    expect(a.length, 1);
  });

  test('enum tokens serialise to real ARIA values', () {
    expect(aria(live: AriaLive.polite)['aria-live'], 'polite');
    expect(aria(current: AriaCurrent.page)['aria-current'], 'page');
  });

  test('composes with a user attrs map without clobbering', () {
    final attrs = {...aria(label: 'Close', expanded: true), 'id': 'x'};
    expect(attrs['id'], 'x');
    expect(attrs['aria-label'], 'Close');
  });

  test('helpers render through the SSR backend', () {
    final html = renderToHtml(
      Div(attrs: {...aria(label: 'Menu', expanded: false), 'id': 'm'},
          text: 'hi'),
    );
    expect(html, contains('aria-label="Menu"'));
    expect(html, contains('aria-expanded="false"'));
    expect(html, contains('id="m"'));
  });

  test('role helper produces a role attribute', () {
    final html = renderToHtml(Div(attrs: ariaAttr('role', 'navigation')));
    expect(html, contains('role="navigation"'));
  });

  test('VisuallyHidden renders text that is present but clipped', () {
    final html = renderToHtml(VisuallyHidden(text: 'skip to content'));
    expect(html, contains('skip to content'));
  });
}
