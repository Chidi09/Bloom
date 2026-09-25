@TestOn('browser')
library;

import 'dart:async';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

BloomRouter _router() => BloomRouter([
      BloomRoute('/', (p) => Div(text: 'home')),
      BloomRoute('/search', (p) => Div(text: 'search')),
      BloomRoute('/docs', (p) => Div(text: 'docs')),
    ]);

class _GateGuard extends BloomRouteGuard {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<GuardResult> canActivate(
      String location, Map<String, String> params) async {
    started.complete();
    await release.future;
    return GuardResult.allow();
  }
}

class _DenyGuard extends BloomRouteGuard {
  @override
  GuardResult canActivate(String location, Map<String, String> params) =>
      GuardResult.deny();
}

class _RedirectGuard extends BloomRouteGuard {
  final String target;

  _RedirectGuard(this.target);

  @override
  GuardResult canActivate(String location, Map<String, String> params) =>
      GuardResult.redirect(target);
}

void main() {
  late BloomRouterController c;

  setUp(() {
    web.window.history.replaceState(null, '', '/');
  });
  tearDown(() {
    c.dispose();
    web.window.history.replaceState(null, '', '/');
  });

  test('navigate exposes the query reactively', () async {
    c = BloomRouterController(_router());
    var ticks = 0;
    final d = effect(() {
      c.currentQuery.value;
      ticks++;
    });
    addTearDown(d.call);
    final before = ticks;

    await c.navigate('/search?q=shoes&page=2');

    expect(c.currentQuery.value['q'], 'shoes');
    expect(c.currentQuery.value['page'], '2');
    expect(c.currentPath.value, '/search',
        reason: 'currentPath must stay clean, without the query');
    expect(ticks, greaterThan(before),
        reason: 'a Live reading currentQuery must re-render');
    expect(web.window.location.search, contains('q=shoes'),
        reason: 'the query must actually reach the address bar');
  });

  test('repeated keys are available via currentQueryAll', () async {
    c = BloomRouterController(_router());
    await c.navigate('/search?tag=a&tag=b');
    expect(c.currentQueryAll.value['tag'], ['a', 'b']);
    expect(c.currentQuery.value['tag'], 'b');
  });

  test('a denied programmatic navigation leaves the URL and route unchanged',
      () async {
    final router = BloomRouter([
      BloomRoute('/', (p) => Div(text: 'home')),
      BloomRoute('/private', (p) => Div(text: 'private'),
          guards: [_DenyGuard()]),
    ]);
    c = BloomRouterController(router);

    await c.navigate('/private');

    expect(c.currentPath.value, '/');
    expect(web.window.location.pathname, '/');
  });

  test('a guarded direct load stays blank until redirected', () async {
    web.window.history.replaceState(null, '', '/private');
    final router = BloomRouter([
      BloomRoute('/private', (p) => H1(text: 'private'),
          guards: [_RedirectGuard('/login')]),
      BloomRoute('/login', (p) => H1(text: 'login')),
    ]);
    c = BloomRouterController(router);

    expect(c.resolve(), isA<FragmentNode>(),
        reason: 'the protected page must not flash before its guard resolves');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(c.currentPath.value, '/login');
    expect(web.window.location.pathname, '/login');
    expect(renderToHtml(c.resolve()), contains('login'));
  });

  test('a denied direct load does not render the protected route', () async {
    web.window.history.replaceState(null, '', '/private');
    final router = BloomRouter([
      BloomRoute('/private', (p) => H1(text: 'private'),
          guards: [_DenyGuard()]),
    ]);
    c = BloomRouterController(router);

    expect(c.resolve(), isA<FragmentNode>());
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(c.resolve(), isA<FragmentNode>());
    expect(web.window.location.pathname, '/private');
  });

  test('a denied back navigation restores the last allowed URL', () async {
    final router = BloomRouter([
      BloomRoute('/safe', (p) => Div(text: 'safe')),
      BloomRoute('/private', (p) => Div(text: 'private'),
          guards: [_DenyGuard()]),
      BloomRoute('/safe-again', (p) => Div(text: 'safe again')),
    ]);
    web.window.history
      ..replaceState(null, '', '/safe')
      ..pushState(null, '', '/private')
      ..pushState(null, '', '/safe-again');
    c = BloomRouterController(router);

    web.window.history.back();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(c.currentPath.value, '/safe-again');
    expect(web.window.location.pathname, '/safe-again');
  });

  test('a redirected back navigation replaces the denied URL', () async {
    final router = BloomRouter([
      BloomRoute('/safe', (p) => Div(text: 'safe')),
      BloomRoute('/private', (p) => Div(text: 'private'),
          guards: [_RedirectGuard('/login')]),
      BloomRoute('/safe-again', (p) => Div(text: 'safe again')),
      BloomRoute('/login', (p) => Div(text: 'login')),
    ]);
    web.window.history
      ..replaceState(null, '', '/safe')
      ..pushState(null, '', '/private')
      ..pushState(null, '', '/safe-again');
    c = BloomRouterController(router);

    web.window.history.back();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(c.currentPath.value, '/login');
    expect(web.window.location.pathname, '/login');
  });

  test('setQuery updates the query without changing the path', () async {
    c = BloomRouterController(_router());
    await c.navigate('/search?q=shoes&page=1');
    await c.setQuery({'q': 'shoes', 'page': '2'});

    expect(c.currentPath.value, '/search');
    expect(c.currentQuery.value['page'], '2');
    expect(web.window.location.pathname, '/search');
  });

  test('the fragment is exposed and scrolls its target into view', () async {
    final tall = web.document.createElement('div') as web.HTMLDivElement;
    tall.style.height = '3000px';
    final anchor = web.document.createElement('div') as web.HTMLDivElement;
    anchor.id = 'section-3';
    anchor.style.height = '100px';
    web.document.body!
      ..appendChild(tall)
      ..appendChild(anchor);
    addTearDown(() {
      tall.remove();
      anchor.remove();
    });

    c = BloomRouterController(_router());
    await c.navigate('/docs#section-3');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(c.currentFragment.value, 'section-3');
    expect(web.window.scrollY, greaterThan(0),
        reason: 'a fragment target must scroll into view, not scroll to top');
  });

  test('a navigation with no fragment still scrolls to top', () async {
    final tall = web.document.createElement('div') as web.HTMLDivElement;
    tall.style.height = '3000px';
    web.document.body!.appendChild(tall);
    addTearDown(() => tall.remove());

    c = BloomRouterController(_router());
    web.window.scrollTo(web.ScrollToOptions(left: 0, top: 500));
    await c.navigate('/search');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(web.window.scrollY, 0);
  });

  test('a missing fragment target falls back without throwing', () async {
    c = BloomRouterController(_router());
    await c.navigate('/docs#does-not-exist');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.currentFragment.value, 'does-not-exist');
  });

  test('navigation moves focus to the new content', () async {
    final h1 = web.document.createElement('h1') as web.HTMLHeadingElement;
    h1.textContent = 'Search';
    web.document.body!.appendChild(h1);
    addTearDown(() => h1.remove());

    c = BloomRouterController(_router());
    await c.navigate('/search');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(web.document.activeElement, isNotNull);
    expect(web.document.activeElement, same(h1),
        reason:
            'focus must land on the new page heading, not stay on the link');
  });

  test('autoFocus: false leaves focus alone', () async {
    final h1 = web.document.createElement('h1') as web.HTMLHeadingElement;
    web.document.body!.appendChild(h1);
    addTearDown(() => h1.remove());

    c = BloomRouterController(_router(), autoFocus: false);
    await c.navigate('/search');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(web.document.activeElement, isNot(same(h1)));
  });

  test('navigation is announced to assistive technology', () async {
    c = BloomRouterController(_router());
    await c.navigate('/search');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final live = web.document.querySelectorAll('[aria-live]');
    expect(live.length, greaterThan(0),
        reason: 'an aria-live region must exist to announce route changes');

    var announced = false;
    for (var i = 0; i < live.length; i++) {
      final el = live.item(i) as web.Element?;
      if ((el?.textContent ?? '').trim().isNotEmpty) announced = true;
    }
    expect(announced, isTrue,
        reason: 'the live region must actually carry the new page text');
  });

  test('dispose removes any announcer node it created', () async {
    final before = web.document.querySelectorAll('[aria-live]').length;
    final c2 = BloomRouterController(_router());
    await c2.navigate('/search');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    c2.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(web.document.querySelectorAll('[aria-live]').length, before,
        reason: 'dispose must not leak a live region into the document');

    // Satisfy tearDown, which disposes `c`.
    c = BloomRouterController(_router());
  });

  test('dispose cancels queued initial navigation work', () async {
    final tall = web.document.createElement('div') as web.HTMLDivElement;
    tall.style.height = '3000px';
    web.document.body!.appendChild(tall);
    addTearDown(() => tall.remove());

    web.window.scrollTo(web.ScrollToOptions(left: 0, top: 500));
    expect(web.window.scrollY, 500);

    c = BloomRouterController(_router());
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(web.window.scrollY, 500,
        reason: 'queued work must not scroll after controller disposal');
  });

  test('dispose prevents an async route guard from changing browser history',
      () async {
    final guard = _GateGuard();
    final router = BloomRouter([
      BloomRoute('/', (p) => Div(text: 'home')),
      BloomRoute('/slow', (p) => Div(text: 'slow'), guards: [guard]),
    ]);
    c = BloomRouterController(router);

    final navigation = c.navigate('/slow');
    await guard.started.future;
    c.dispose();
    guard.release.complete();
    await navigation;

    expect(web.window.location.pathname, '/');
    expect(c.currentPath.value, '/');
  });
}
