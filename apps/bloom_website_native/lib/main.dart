import 'dart:js_interop';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

import 'components/command_palette.dart';
import 'components/theme_toggle.dart';
import 'components/toast_system.dart';
import 'pages/blocks_page.dart';
import 'pages/bloom_page.dart';
import 'pages/build_page.dart';
import 'pages/home_page.dart';
import 'pages/server_page.dart';
import 'pages/ship_page.dart';

final pageTitles = <String, String>{
  '/':
      'Bloom — BUILD • SHIP • BLOOM | The Application Platform for Dart & Flutter',
  '/build': 'BUILD — Bloom Framework & Developer Experience',
  '/ship': 'SHIP — Bloom Cloud OTA & Deploy Pipeline',
  '/bloom': 'BLOOM — UI Studio & Interactive Mobile Component System',
  '/server': 'Bloom Server — Pure Dart Backend Platform & Ecosystem',
  '/blocks': 'Application Blocks — Bloom UI Primitives',
};

void main() {
  // Restore persisted theme before first render so SSR/hydration markup and
  // the toggle's signal start in sync with `bloom-theme` in localStorage.
  _restorePersistedTheme();

  // Browser-only hooks: the components themselves stay SSR-safe.
  copyToClipboard = (text) {
    web.window.navigator.clipboard.writeText(text);
  };
  focusPaletteInput = (element) {
    if (element is web.HTMLInputElement) element.focus();
  };
  applyThemeToDocument = _applyTheme;

  final router = BloomRouter([
    BloomRoute('/', (_) => homePage()),
    BloomRoute('/bloom', (_) => bloomPage()),
    BloomRoute('/build', (_) => buildPage()),
    BloomRoute('/ship', (_) => shipPage()),
    BloomRoute('/server', (_) => serverPage()),
    BloomRoute('/blocks', (_) => blocksPage()),
  ]);

  final controller = BloomRouterController(router);

  final app = Div(
    children: [
      Live(() {
        final _ = controller.currentPath.value;
        return controller.resolve();
      }),
      commandPaletteViewport(),
      siteToastViewport(),
    ],
  );

  // The SSG has already rendered #app. Hydration attaches in place when the
  // descriptor is static and otherwise performs one clean remount; `mount`
  // would append a second copy of the complete page beside the SSR markup.
  hydrate(app, '#app');
  // Sync document classes with the restored theme now that the DOM exists.
  _applyTheme(isDarkTheme.value);
  web.window.dispatchEvent(web.CustomEvent('bloom:mounted'));
  _revealVisibleElements();

  controller.currentPath.subscribe((path) {
    final title = pageTitles[path];
    if (title != null) {
      web.document.title = title;
    }
    web.window.dispatchEvent(web.CustomEvent('bloom:mounted'));
    _revealVisibleElements();
  });

  // Global Keyboard Shortcut Handler (Cmd+K / Ctrl+K / Escape)
  web.window.addEventListener(
    'keydown',
    (web.KeyboardEvent event) {
      final key = event.key;
      final isMeta = event.metaKey || event.ctrlKey;

      if (isMeta && (key == 'k' || key == 'K')) {
        event.preventDefault();
        if (isPaletteOpen.value) {
          closePalette();
        } else {
          openPalette();
        }
      } else if (key == 'Escape' && isPaletteOpen.value) {
        closePalette();
      }
    }.toJS,
  );

  // Navbar Search button / mobile menu / page layout all dispatch this custom
  // event — it is the canonical "open palette" channel.
  web.window.addEventListener(
    'bloom:open-cmd-palette',
    (web.Event _) {
      openPalette();
    }.toJS,
  );

  // Bind Search Trigger Button and Link Interception
  web.document.addEventListener(
    'click',
    (web.MouseEvent event) {
      final target = event.target;
      if (target is web.Element) {
        final searchBtn = target.closest('#search-trigger');
        if (searchBtn != null) {
          openPalette();
          return;
        }

        // Link click interception for SPA navigation
        final anchor = target.closest('a');
        if (anchor is web.HTMLAnchorElement && anchor.href.isNotEmpty) {
          final href = anchor.getAttribute('href');
          final isExternal =
              anchor.target == '_blank' ||
              (href != null &&
                  (href.startsWith('http://') || href.startsWith('https://')));
          if (!isExternal && href != null && href.startsWith('/')) {
            event.preventDefault();
            controller.navigate(href);
          }
        }
      }
    }.toJS,
  );

  // Mouse Glow positioning on cards
  web.document.addEventListener(
    'mousemove',
    (web.MouseEvent event) {
      final cards = web.document.querySelectorAll('.mouse-glow-card');
      for (var i = 0; i < cards.length; i++) {
        final card = cards.item(i);
        if (card is web.HTMLElement) {
          final rect = card.getBoundingClientRect();
          final x = event.clientX - rect.left;
          final y = event.clientY - rect.top;
          card.style.setProperty('--mouse-x', '${x}px');
          card.style.setProperty('--mouse-y', '${y}px');
        }
      }
    }.toJS,
  );

  // Hydration can replace the SSR-only page-layout script, so scroll reveal
  // registration belongs in the browser entry point. Only entering elements
  // receive `is-visible`; eagerly revealing all elements skips the animation.
  web.window.addEventListener(
    'scroll',
    ((web.Event _) => _revealVisibleElements()).toJS,
  );
}

void _restorePersistedTheme() {
  try {
    final stored = web.window.localStorage.getItem('bloom-theme');
    // Default is dark, matching class="dark" on <html> in web/index.html.
    isDarkTheme.value = stored != 'light';
  } catch (_) {
    isDarkTheme.value = true;
  }
}

/// Applies theme state to the document and persists it. Light mode must not
/// be overridden by the dark defaults baked into web/index.html's <body>
/// classes (`bg-black text-white`), so those are toggled here as well.
void _applyTheme(bool dark) {
  final root = web.document.documentElement;
  if (root != null) {
    root.classList.toggle('dark', dark);
    root.classList.toggle('light', !dark);
    (root as web.HTMLElement).style.setProperty(
      'color-scheme',
      dark ? 'dark' : 'light',
    );
  }

  try {
    web.window.localStorage.setItem('bloom-theme', dark ? 'dark' : 'light');
  } catch (_) {}

  final body = web.document.body;
  if (body != null) {
    body.classList.toggle('bg-black', dark);
    body.classList.toggle('text-white', dark);
    body.classList.toggle('bg-slate-50', !dark);
    body.classList.toggle('text-slate-900', !dark);
  }
}

void _revealVisibleElements() {
  try {
    final elements = web.document.querySelectorAll('.scroll-reveal');
    final revealBoundary = web.window.innerHeight - 40;
    for (var i = 0; i < elements.length; i++) {
      final item = elements.item(i);
      if (item is web.HTMLElement) {
        if (item.getBoundingClientRect().top <= revealBoundary) {
          item.classList.add('is-visible');
        }
      }
    }
  } catch (_) {}
}
