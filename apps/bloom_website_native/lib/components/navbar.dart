import 'package:bloom_js_native/bloom_js_native.dart';
import 'huge_icons.dart';
import 'petal_logo.dart';
import 'theme_toggle.dart';

BloomNode navbar({required String currentPath, String petalHighlight = 'all'}) {
  bool isActive(String path) {
    if (path == '/' && currentPath == '/') return true;
    if (path != '/' && currentPath.startsWith(path)) return true;
    return false;
  }

  return Header(
    className:
        'sticky top-0 z-50 backdrop-blur-2xl bg-white/80 '
        'dark:bg-black/90 border-b border-slate-200/80 '
        'dark:border-zinc-800/80 transition-colors duration-500',
    children: [
      Div(
        className:
            'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex '
            'items-center justify-between',
        children: [
          // Brand Logo
          A(
            href: '/',
            className:
                'flex items-center gap-3 group focus:outline-none '
                'relative shrink-0',
            children: [
              Div(
                className:
                    'absolute inset-0 bg-purple-500/20 blur-xl rounded-full '
                    'scale-0 group-hover:scale-150 transition-transform '
                    'duration-500',
              ),
              petalLogo(highlight: petalHighlight, size: 36),
              Div(
                className: 'flex flex-col',
                children: [
                  Span(
                    className:
                        'font-black text-2xl tracking-tight text-slate-900 '
                        'dark:text-white leading-none',
                    text: 'bloom',
                  ),
                  Span(
                    className:
                        'text-[9px] font-mono tracking-[0.2em] font-extrabold '
                        'uppercase mt-0.5 text-slate-500 dark:text-slate-400 flex '
                        'items-center gap-1',
                    children: [
                      Span(
                        className: isActive('/build')
                            ? 'text-purple-500 underline font-black'
                            : 'text-purple-500',
                        text: 'BUILD',
                      ),
                      Span(className: 'text-pink-500', text: '•'),
                      Span(
                        className: isActive('/ship')
                            ? 'text-blue-500 underline font-black'
                            : 'text-blue-500',
                        text: 'SHIP',
                      ),
                      Span(className: 'text-cyan-500', text: '•'),
                      Span(
                        className: isActive('/bloom')
                            ? 'text-orange-500 underline font-black'
                            : 'text-orange-500',
                        text: 'BLOOM',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Nav Links (XL Screens)
          Nav(
            className:
                'hidden xl:flex items-center gap-1 text-xs font-semibold '
                'text-slate-600 dark:text-slate-300 bg-white/50 '
                'dark:bg-zinc-950/80 p-1 rounded-2xl border '
                'border-slate-200/60 dark:border-zinc-800/80 shadow-sm '
                'backdrop-blur-md',
            children: [
              A(
                href: '/',
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all ${isActive('/') && currentPath == '/' ? 'bg-white dark:bg-zinc-900 text-slate-900 dark:text-white shadow-sm font-bold' : 'hover:bg-white/60 dark:hover:bg-zinc-900/60 hover:text-slate-900 dark:hover:text-white'}',
                text: 'Hub',
              ),
              A(
                href: '/build',
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all ${isActive('/build') ? 'bg-white dark:bg-zinc-900 text-purple-600 dark:text-purple-400 shadow-sm font-bold' : 'hover:bg-white/60 dark:hover:bg-zinc-900/60 hover:text-slate-900 dark:hover:text-white'}',
                text: 'App (Client)',
              ),
              A(
                href: '/server',
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all ${isActive('/server') ? 'bg-white dark:bg-zinc-900 text-pink-600 dark:text-pink-400 shadow-sm font-bold' : 'hover:bg-white/60 dark:hover:bg-zinc-900/60 hover:text-slate-900 dark:hover:text-white'}',
                text: 'Server (Backend)',
              ),
              A(
                href: '/ship',
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all ${isActive('/ship') ? 'bg-white dark:bg-zinc-900 text-blue-600 dark:text-blue-400 shadow-sm font-bold' : 'hover:bg-white/60 dark:hover:bg-zinc-900/60 hover:text-slate-900 dark:hover:text-white'}',
                text: 'Cloud & CLI',
              ),
              A(
                href: '/bloom',
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all ${isActive('/bloom') ? 'bg-white dark:bg-zinc-900 text-cyan-600 dark:text-cyan-400 shadow-sm font-bold' : 'hover:bg-white/60 dark:hover:bg-zinc-900/60 hover:text-slate-900 dark:hover:text-white'}',
                text: 'UI & Blocks',
              ),
              A(
                href: 'https://github.com/Chidi09/Bloom',
                attrs: const {'target': '_blank'},
                className:
                    'px-2.5 py-1.5 rounded-xl transition-all '
                    'hover:bg-white/60 dark:hover:bg-zinc-900/60 '
                    'hover:text-slate-900 dark:hover:text-white',
                text: 'Docs',
              ),
            ],
          ),

          // Actions
          Div(
            className: 'flex items-center gap-2.5 shrink-0',
            children: [
              // Theme Toggle
              themeToggle(),

              // Search Trigger Button (Cmd+K)
              Button(
                attrs: const {
                  'id': 'search-trigger',
                  'type': 'button',
                  'aria-label': 'Open Command Palette',
                  'onclick':
                      "window.dispatchEvent(new CustomEvent('bloom:open-cmd-palette'))",
                },
                className:
                    'hidden sm:flex items-center gap-2 px-3 py-1.5 '
                    'bg-white/60 dark:bg-zinc-900/80 backdrop-blur border '
                    'border-slate-200 dark:border-zinc-800 rounded-xl text-xs '
                    'font-mono text-slate-500 dark:text-slate-400 '
                    'hover:border-purple-400 dark:hover:border-purple-500 '
                    'transition shadow-sm group',
                children: [
                  El(
                    'svg',
                    className:
                        'w-3.5 h-3.5 text-slate-400 group-hover:text-purple-500 '
                        'transition-colors',
                    attrs: {
                      'fill': 'none',
                      'viewBox': '0 0 24 24',
                      'stroke': 'currentColor',
                    },
                    children: [
                      El(
                        'path',
                        attrs: {
                          'stroke-linecap': 'round',
                          'stroke-linejoin': 'round',
                          'stroke-width': '2',
                          'd': 'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z',
                        },
                      ),
                    ],
                  ),
                  Span(text: 'Search'),
                  El(
                    'kbd',
                    className:
                        'px-1.5 py-0.5 text-[10px] bg-slate-100 dark:bg-zinc-800 '
                        'border border-slate-200 dark:border-zinc-700 rounded '
                        'text-slate-500 dark:text-slate-400 font-bold ml-1.5',
                    text: '⌘K',
                  ),
                ],
              ),

              // Get Started Conic-Gradient Action
              A(
                href: '/build',
                className:
                    'relative overflow-hidden rounded-xl p-[1px] group hidden '
                    '2xl:block',
                children: [
                  Span(
                    className:
                        'absolute inset-[-1000%] '
                        'animate-[spin_4s_linear_infinite] '
                        'bg-[conic-gradient(from_90deg_at_50%_50%,#393BB2_0%,#8B5CF6_50%,#393BB2_100%)]',
                  ),
                  Div(
                    className:
                        'inline-flex h-9 items-center justify-center '
                        'rounded-[11px] bg-white dark:bg-black px-4 py-1 text-xs '
                        'font-bold text-slate-900 dark:text-white '
                        'backdrop-blur-3xl transition-transform '
                        'group-hover:scale-[0.98] gap-1.5',
                    children: [
                      Span(
                        className:
                            'w-2 h-2 rounded-full bg-emerald-400 '
                            'shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse',
                      ),
                      Span(text: 'Get Started'),
                    ],
                  ),
                ],
              ),

              // Mobile Hamburger Button
              Button(
                attrs: const {
                  'id': 'mobile-menu-btn',
                  'type': 'button',
                  'aria-label': 'Toggle menu',
                  'onclick': 'window.toggleBloomMobileMenu()',
                },
                className:
                    'xl:hidden p-2.5 rounded-xl text-slate-700 '
                    'dark:text-slate-200 hover:bg-slate-200/60 '
                    'dark:hover:bg-zinc-800 transition active:scale-95',
                children: [
                  Span(
                    attrs: const {'id': 'menu-icon-open'},
                    className: 'block',
                    children: [hugeIcon('menu', className: 'w-6 h-6')],
                  ),
                  Span(
                    attrs: const {'id': 'menu-icon-close'},
                    className: 'hidden',
                    children: [hugeIcon('x', className: 'w-6 h-6')],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Fullscreen Backdrop Blur Overlay when Hamburger Menu is Open
      Div(
        attrs: const {
          'id': 'mobile-menu-backdrop',
          'onclick': 'window.closeBloomMobileMenu()',
        },
        className:
            'hidden xl:hidden fixed inset-0 top-[64px] bg-black/60 '
            'dark:bg-black/80 backdrop-blur-2xl z-30 '
            'transition-opacity duration-300',
      ),

      // Mobile Dropdown Menu
      Div(
        attrs: const {'id': 'mobile-menu'},
        className:
            'hidden xl:hidden bg-white/95 dark:bg-black/95 '
            'backdrop-blur-3xl border-b border-slate-200/80 '
            'dark:border-zinc-800 absolute w-full left-0 top-[64px] '
            'shadow-2xl origin-top transition-all duration-300 '
            'ease-in-out z-40',
        children: [
          Div(
            className:
                'px-4 pt-4 pb-6 space-y-1.5 flex flex-col font-semibold '
                'text-slate-700 dark:text-slate-300',
            children: [
              A(
                href: '/',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-slate-100 '
                    'dark:hover:bg-zinc-900',
                text: 'Hub',
              ),
              A(
                href: '/build',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-purple-100 '
                    'dark:hover:bg-purple-900/30 text-purple-600 '
                    'dark:text-purple-400 font-bold',
                text: 'App / Client (Flutter & Web)',
              ),
              A(
                href: '/server',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-pink-100 '
                    'dark:hover:bg-pink-900/30 text-pink-600 '
                    'dark:text-pink-400 font-bold',
                text: 'Bloom Server (Backend & ORM)',
              ),
              A(
                href: '/ship',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-blue-100 '
                    'dark:hover:bg-blue-900/30 text-blue-600 '
                    'dark:text-blue-400 font-bold',
                text: 'Cloud & CLI Tooling',
              ),
              A(
                href: '/bloom',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-cyan-100 '
                    'dark:hover:bg-cyan-900/30 text-cyan-600 '
                    'dark:text-cyan-400',
                text: 'UI Components Gallery',
              ),
              A(
                href: '/build',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-pink-100 '
                    'dark:hover:bg-pink-900/30 text-pink-600 '
                    'dark:text-pink-400',
                text: 'Application Blocks',
              ),
              A(
                href: '/bloom',
                attrs: const {'onclick': 'window.closeBloomMobileMenu()'},
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-amber-100 '
                    'dark:hover:bg-amber-900/30 text-amber-600 '
                    'dark:text-amber-400',
                text: 'Theme Studio',
              ),
              A(
                href: 'https://github.com/Chidi09/Bloom',
                attrs: const {
                  'onclick': 'window.closeBloomMobileMenu()',
                  'target': '_blank',
                },
                className:
                    'block px-4 py-2.5 rounded-xl hover:bg-purple-100 '
                    'dark:hover:bg-purple-900/30 text-purple-600 '
                    'dark:text-purple-400',
                text: 'Documentation Home',
              ),
              El('hr', className: 'border-slate-200 dark:border-zinc-800 my-2'),
              Button(
                attrs: const {
                  'type': 'button',
                  'onclick':
                      "window.dispatchEvent(new CustomEvent('bloom:open-cmd-palette')); window.closeBloomMobileMenu();",
                },
                className:
                    'flex items-center gap-2 px-4 py-2.5 bg-slate-100 '
                    'dark:bg-zinc-900 rounded-xl hover:bg-slate-200 '
                    'dark:hover:bg-zinc-800 transition text-left w-full',
                children: [
                  hugeIcon('search', className: 'w-4 h-4 text-slate-500'),
                  Span(text: 'Search Documentation (⌘K)'),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
