import 'package:bloom_js_native/bloom_js_native.dart';
import '../design/tokens.dart';
import '../state/cart.dart';
import 'ui.dart';

BloomNode appShell(BloomNode content, {String title = 'Marketplace'}) {
  return Fragment(children: [
    Style(designTokensCss),
    Div(
      className: 'min-h-screen flex flex-col bg-[var(--bg)] text-[var(--text)]',
      children: [
        _header(),
        Main(
          attrs: aria(role: AriaRole.main),
          className: 'flex-1 w-full max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-8',
          children: [content],
        ),
        _footer(),
      ],
    ),
  ]);
}

BloomNode _header() {
  return El('header',
    className: 'sticky top-0 z-20 backdrop-blur bg-[var(--bg)]/90 border-b border-[var(--border)]',
    children: [
      Div(
        className: 'max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 h-14 flex items-center justify-between gap-4',
        children: [
          Link(
            href: '/',
            className: 'inline-flex items-center gap-2 font-semibold text-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] rounded-md px-1',
            children: [
              Span(className: 'w-7 h-7 rounded-md bg-[var(--brand-600)] text-white grid place-items-center text-sm font-bold', text: 'M'),
              Span(className: 'tracking-tight', style: 'font-family:var(--font-display)', text: 'Marketplace'),
            ],
          ),
          Nav(
            attrs: aria(role: AriaRole.navigation, label: 'Primary'),
            className: 'hidden sm:flex items-center gap-1 text-sm',
            children: [
              Link(href: '/', className: 'px-3 py-1.5 rounded-md hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'Catalog'),
            ],
          ),
          Div(className: 'flex items-center gap-2', children: [
            Live(() {
              final count = cartItemCount;
              final ariaLabel = count > 0 ? 'Cart, $count ${count == 1 ? 'item' : 'items'}' : 'Cart, empty';
              return Link(
                href: '/cart',
                attrs: {'aria-label': ariaLabel},
                className: 'relative inline-flex items-center justify-center p-2 rounded-md border border-[var(--border)] text-[var(--text)] hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
                children: [
                  hugeIcon('shopping', className: 'w-4 h-4'),
                  if (count > 0)
                    Span(
                      className: 'absolute -top-1.5 -right-1.5 min-w-[1.125rem] h-[1.125rem] px-1 rounded-full bg-[var(--brand-600)] text-white text-[10px] font-bold flex items-center justify-center leading-none tabular',
                      text: '$count',
                    ),
                ],
              );
            }),
            Link(
              href: '/admin',
              className: 'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md border border-[var(--border)] text-sm font-medium hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]',
              children: [Span(text: 'Dashboard')],
            ),
          ]),
        ],
      ),
    ],
  );
}

BloomNode _footer() {
  return El('footer',
    className: 'border-t border-[var(--border)] py-6 text-center text-sm text-[var(--text-muted)]',
    children: [
      P(text: '© 2026 Marketplace • Deterministic benchmark storefront • Demo only'),
    ],
  );
}

BloomNode adminShell(BloomNode content) {
  // Dark mode on admin per spec: token-level dark done globally; admin forces dark via data-theme
  return Fragment(children: [
    Style(designTokensCss),
    Div(
      attrs: {'data-theme': 'dark'},
      className: 'min-h-screen flex bg-[var(--bg)] text-[var(--text)]',
      children: [
        // Sidebar 240px
        El('aside',
          className: 'hidden lg:flex w-[240px] shrink-0 flex-col border-r border-[var(--border)] bg-[var(--bg-soft)] sticky top-0 h-screen',
          children: [
            Div(className: 'h-14 flex items-center gap-2 px-5 border-b border-[var(--border)]', children: [
              Span(className: 'w-7 h-7 rounded-md bg-[var(--brand-600)] text-white grid place-items-center text-sm font-bold', text: 'M'),
              Span(className: 'font-semibold', style: 'font-family:var(--font-display)', text: 'Admin'),
            ]),
            Nav(
              attrs: aria(role: AriaRole.navigation, label: 'Admin'),
              className: 'flex flex-col gap-1 p-3 text-sm',
              children: [
                _adminLink('/', 'Storefront'),
                _adminLink('/admin', 'Overview'),
                _adminLink('/admin/products', 'Products'),
              ],
            ),
            Div(
              className: 'mt-auto p-4 flex items-center gap-2.5 border-t border-[var(--border)] text-xs text-[var(--text-muted)]',
              children: [
                Span(className: 'w-6 h-6 rounded-full bg-[var(--bg-muted)] border border-[var(--border)] grid place-items-center text-[10px] font-medium text-[var(--text)]', text: 'A'),
                Span(className: 'font-medium text-[var(--text)]', text: 'Admin'),
              ],
            ),
          ],
        ),
        Div(className: 'flex-1 min-w-0 flex flex-col', children: [
          // top bar
          Div(className: 'sticky top-0 z-10 h-14 flex items-center justify-between gap-4 px-4 lg:px-6 border-b border-[var(--border)] bg-[var(--bg)]', children: [
            Span(className: 'font-medium', text: 'Marketplace Admin'),
            Link(href: '/admin/products/new', className: 'inline-flex items-center px-3 py-1.5 rounded-md bg-[var(--brand-600)] text-white text-sm font-medium hover:bg-[var(--brand-700)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)]', text: 'New product'),
          ]),
          // mobile nav bar below top bar
          El('nav',
            attrs: aria(role: AriaRole.navigation, label: 'Admin mobile'),
            className: 'flex lg:hidden items-center gap-2 px-4 py-2 border-b border-[var(--border)] bg-[var(--bg-soft)] text-sm overflow-x-auto',
            children: [
              _adminLink('/', 'Storefront'),
              _adminLink('/admin', 'Overview'),
              _adminLink('/admin/products', 'Products'),
            ],
          ),
          Main(
            attrs: aria(role: AriaRole.main),
            className: 'flex-1 max-w-[1440px] w-full mx-auto p-4 lg:p-6',
            children: [content],
          ),
        ]),
      ],
    ),
  ]);
}

BloomNode _adminLink(String href, String label) {
  return Link(
    href: href,
    className: 'px-3 py-2 rounded-md hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] flex items-center gap-2',
    children: [Span(text: label)],
  );
}
