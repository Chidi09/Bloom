/// Top sticky navigation bar with section links, social shortcuts, and theme toggle.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import '../plugins/lenis_scroll.dart';
import '../plugins/lucide_icons.dart';
import '../theme.dart';

/// Top-level navigation header component.
class NavbarComponent {
  final ThemeManager _theme = ThemeManager.instance;

  BloomNode build() {
    return Header(
      className:
          'fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-zinc-950/80 border-b border-zinc-800/60 transition-colors duration-200',
      attrs: aria(role: AriaRole.banner),
      children: [
        Div(
          className:
              'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between',
          children: [
            // Brand / Monogram
            Button(
              attrs: {
                'type': 'button',
                ...aria(
                  label: 'Alex Rivera Portfolio — Return to top of page',
                ),
              },
              className:
                  'flex items-center gap-2.5 font-mono text-sm font-semibold tracking-tight text-zinc-100 hover:text-indigo-400 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 rounded-md p-1',
              onClick: (_) => LenisScroll.scrollTo('#hero', offset: 0),
              children: [
                Span(
                  className:
                      'w-8 h-8 rounded-lg bg-indigo-600/20 border border-indigo-500/40 flex items-center justify-center text-indigo-400 font-bold text-xs',
                  text: 'AR',
                ),
                Span(
                  className: 'hidden sm:inline font-mono tracking-wider',
                  text: 'alex.rivera',
                ),
              ],
            ),

            // Navigation Links
            Nav(
              attrs: aria(role: AriaRole.navigation, label: 'Main Navigation'),
              className: 'hidden md:flex items-center gap-8 text-sm font-medium',
              children: [
                _navLink('About', '#about'),
                _navLink('Projects', '#projects'),
                _navLink('Activity', '#activity'),
                _navLink('Contact', '#contact'),
              ],
            ),

            // Actions: GitHub shortcut + Theme Toggle
            Div(
              className: 'flex items-center gap-3',
              children: [
                // GitHub profile external link
                A(
                  href: 'https://github.com/Chidi09',
                  target: '_blank',
                  rel: 'noopener noreferrer',
                  className:
                      'p-2 rounded-lg text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/60 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                  attrs: aria(label: 'View Alex Rivera on GitHub (opens in new tab)'),
                  children: [
                    Raw(LucideIcons.svg(LucideIconName.github, className: 'w-5 h-5')),
                  ],
                ),

                // Dark/Light Mode Switcher
                Button(
                  attrs: {
                    'type': 'button',
                    ...aria(
                      label: 'Toggle dark and light visual theme',
                    ),
                  },
                  className:
                      'p-2 rounded-lg text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800/60 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                  onClick: (_) => _theme.toggle(),
                  children: [
                    Live(() {
                      final dark = _theme.isDark.value;
                      return Raw(
                        LucideIcons.svg(
                          dark ? LucideIconName.sun : LucideIconName.moon,
                          className: 'w-5 h-5 text-amber-400',
                        ),
                      );
                    }),
                  ],
                ),

                // "Get in Touch" Quick CTA
                Button(
                  attrs: {
                    'type': 'button',
                    ...aria(
                      label: 'Scroll to contact form',
                    ),
                  },
                  className:
                      'hidden sm:inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm shadow-indigo-500/20 transition-all hover:scale-[1.02] focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                  onClick: (_) => LenisScroll.scrollTo('#contact'),
                  children: [
                    Span(text: 'Hire Me'),
                    Raw(LucideIcons.svg(LucideIconName.arrowUpRight, className: 'w-3.5 h-3.5')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _navLink(String label, String target) {
    return Button(
      attrs: {
        'type': 'button',
        ...aria(
          label: 'Navigate to $label section',
        ),
      },
      className:
          'text-zinc-400 hover:text-zinc-100 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 rounded px-1.5 py-1',
      onClick: (_) => LenisScroll.scrollTo(target),
      text: label,
    );
  }
}
