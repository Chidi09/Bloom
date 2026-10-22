import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

class _FakeNavigator implements BloomNavigator {
  @override
  final Signal<String> currentPath = signal('/');

  @override
  Future<void> navigate(String path) async {}

  @override
  Future<void> replace(String path) async {}

  @override
  Future<void> navigateFragment(String fragment) async {}
}

void main() {
  final location = Uri(scheme: 'https', host: 'example.com', path: '/start');

  BloomEvent click({
    int? button,
    bool meta = false,
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
    bool prevented = false,
  }) {
    final event = BloomEvent(
      type: 'click',
      button: button,
      metaKey: meta,
      ctrlKey: ctrl,
      shiftKey: shift,
      altKey: alt,
    );
    if (prevented) event.preventDefault();
    return event;
  }

  bool intercept(
    String href, {
    BloomEvent? event,
    String? target,
    bool download = false,
  }) =>
      shouldInterceptLinkClick(
        href: href,
        event: event ?? click(),
        target: target,
        download: download,
        currentLocation: location,
      );

  group('shouldInterceptLinkClick', () {
    test('handles a plain left click and same-origin links', () {
      expect(intercept('/next'), isTrue);
      expect(intercept('https://example.com/next'), isTrue);
      expect(intercept('#section'), isTrue);
    });

    test('ignores modifier clicks and non-primary buttons', () {
      expect(intercept('/next', event: click(meta: true)), isFalse);
      expect(intercept('/next', event: click(ctrl: true)), isFalse);
      expect(intercept('/next', event: click(shift: true)), isFalse);
      expect(intercept('/next', event: click(alt: true)), isFalse);
      expect(intercept('/next', event: click(button: 1)), isFalse);
    });

    test('ignores targets, downloads, and non-http schemes', () {
      expect(intercept('/next', target: '_blank'), isFalse);
      expect(intercept('/next', target: '_self'), isTrue);
      expect(intercept('/next', download: true), isFalse);
      expect(intercept('mailto:hello@example.com'), isFalse);
      expect(intercept('tel:123'), isFalse);
      expect(intercept('javascript:alert(1)'), isFalse);
      expect(intercept('custom:value'), isFalse);
    });

    test('ignores external origins, empty hrefs, and prevented events', () {
      expect(intercept('https://other.example/'), isFalse);
      expect(intercept(''), isFalse);
      expect(intercept('/next', event: click(prevented: true)), isFalse);
    });
  });

  group('RouterLink SSR', () {
    test('renders href and active class and aria-current', () {
      final nav = _FakeNavigator()..currentPath.value = '/docs';
      final html = renderToHtml(RouterLink(
        controller: nav,
        href: '/docs',
        activeClassName: 'active',
        text: 'Docs',
      ));
      expect(html, contains('href="/docs"'));
      expect(html, contains('class="active"'));
      expect(html, contains('aria-current="page"'));
    });

    test('does not mark nonmatching routes active', () {
      final nav = _FakeNavigator()..currentPath.value = '/other';
      final html = renderToHtml(RouterLink(
        controller: nav,
        href: '/docs',
        activeClassName: 'active',
      ));
      expect(html, isNot(contains('class="active"')));
      expect(html, isNot(contains('aria-current')));
    });

    test('matches prefixes unless exact and treats root as exact only', () {
      final nav = _FakeNavigator()..currentPath.value = '/docs/api';
      expect(
        renderToHtml(RouterLink(
          controller: nav,
          href: '/docs',
          activeClassName: 'active',
        )),
        contains('aria-current="page"'),
      );
      expect(
        renderToHtml(RouterLink(
          controller: nav,
          href: '/docs',
          exact: true,
          activeClassName: 'active',
        )),
        isNot(contains('aria-current')),
      );
      expect(
        renderToHtml(RouterLink(
          controller: nav,
          href: '/',
          activeClassName: 'active',
        )),
        isNot(contains('aria-current')),
      );
      nav.currentPath.value = '/';
      expect(
        renderToHtml(RouterLink(
          controller: nav,
          href: '/',
          activeClassName: 'active',
        )),
        contains('aria-current="page"'),
      );
    });
  });
}
