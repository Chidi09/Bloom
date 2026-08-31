import 'dart:js_interop';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;

import 'package:bloom_website_native/components/command_palette.dart';
import 'package:bloom_website_native/components/toast_system.dart';
import 'package:bloom_website_native/pages/bloom_page.dart';
import 'package:bloom_website_native/pages/build_page.dart';
import 'package:bloom_website_native/pages/home_page.dart';
import 'package:bloom_website_native/pages/server_page.dart';
import 'package:bloom_website_native/pages/ship_page.dart';

void main() {
  final router = BloomRouter([
    BloomRoute('/', (_) => homePage()),
    BloomRoute('/bloom', (_) => bloomPage()),
    BloomRoute('/build', (_) => buildPage()),
    BloomRoute('/ship', (_) => shipPage()),
    BloomRoute('/server', (_) => serverPage()),
  ]);

  final controller = BloomRouterController(router);

  final app = Div(
    children: [
      Live(() => controller.resolve()),
      commandPaletteViewport(),
      siteToastViewport(),
    ],
  );

  mount(app, '#app');

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
          final isExternal = anchor.target == '_blank' ||
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
}
