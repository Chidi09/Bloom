import 'package:bloom_js_native/bloom_js_native.dart';
import 'petal_logo.dart';

BloomNode footer({
  String nextChapterTitle = 'Ship with Cloud OTA',
  String nextChapterLink = '/ship',
  String nextChapterSubtitle =
      'Push instant byte-patches to live apps without App Store review delays.',
}) {
  final firstWord = nextChapterTitle.split(' ').first;

  return Footer(
    className:
        'bg-white/80 dark:bg-black/80 backdrop-blur-xl border-t '
        'border-slate-200 dark:border-zinc-800 pt-16 pb-8 '
        'relative z-10',
    children: [
      Div(
        className: 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8',
        children: [
          // Narrative Cross-Linking CTA Banner (Monochromatic Vercel-Style)
          Div(
            className:
                'mb-16 p-8 sm:p-10 rounded-3xl bg-slate-50 dark:bg-black '
                'border border-slate-200 dark:border-zinc-800 flex '
                'flex-col md:flex-row items-start md:items-center '
                'justify-between gap-6 relative overflow-hidden group',
            children: [
              Div(
                className: 'space-y-2 max-w-xl',
                children: [
                  Span(
                    className:
                        'text-xs font-mono font-bold uppercase tracking-wider '
                        'text-slate-500 dark:text-slate-400 block',
                    text: 'Next Chapter',
                  ),
                  H3(
                    className:
                        'text-2xl sm:text-3xl font-black text-slate-900 '
                        'dark:text-white',
                    text: nextChapterTitle,
                  ),
                  P(
                    className:
                        'text-sm text-slate-600 dark:text-slate-400 '
                        'leading-relaxed',
                    text: nextChapterSubtitle,
                  ),
                ],
              ),
              A(
                href: nextChapterLink,
                className:
                    'px-6 py-3.5 bg-slate-900 dark:bg-white '
                    'hover:bg-slate-800 dark:hover:bg-slate-100 text-white '
                    'dark:text-slate-900 rounded-xl font-bold text-sm '
                    'shadow-lg transition-transform active:scale-95 flex '
                    'items-center gap-2 shrink-0 group-hover:translate-x-1',
                children: [
                  Span(text: 'Continue to $firstWord'),
                  El(
                    'svg',
                    className: 'w-4 h-4 text-slate-400 dark:text-slate-600',
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
                          'd': 'M14 5l7 7m0 0l-7 7m7-7H3',
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Main Footer Grid
          Div(
            className:
                'flex flex-col md:flex-row justify-between items-start '
                'gap-8 mb-16',
            children: [
              Div(
                className: 'space-y-4 max-w-sm',
                children: [
                  A(
                    href: '/',
                    className: 'flex items-center gap-3',
                    children: [
                      petalLogo(highlight: 'all', size: 32),
                      Span(
                        className:
                            'font-black text-xl text-slate-900 dark:text-white',
                        text: 'bloom',
                      ),
                    ],
                  ),
                  P(
                    className:
                        'text-sm text-slate-500 dark:text-slate-400 '
                        'leading-relaxed',
                    text:
                        'The opinionated application platform for Dart & Flutter. '
                        'Framework, Cloud OTA, and UI tokens working as one '
                        'system.',
                  ),
                ],
              ),
              Div(
                className:
                    'grid grid-cols-2 sm:grid-cols-4 gap-6 sm:gap-8 text-sm '
                    'w-full md:w-auto',
                children: [
                  Div(
                    className: 'space-y-3',
                    children: [
                      H4(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: 'Platform',
                      ),
                      A(
                        href: '/build',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'Framework (BUILD)',
                      ),
                      A(
                        href: '/ship',
                        className:
                            'block text-slate-500 hover:text-blue-500 transition',
                        text: 'Cloud OTA (SHIP)',
                      ),
                      A(
                        href: '/bloom',
                        className:
                            'block text-slate-500 hover:text-pink-500 transition',
                        text: 'UI Studio (BLOOM)',
                      ),
                      A(
                        href: '/blocks',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'App Blocks',
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-3',
                    children: [
                      H4(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: 'Documentation',
                      ),
                      A(
                        href: 'https://github.com/Chidi09/Bloom',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'Introduction',
                      ),
                      A(
                        href: 'https://github.com/Chidi09/Bloom',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'Quickstart',
                      ),
                      A(
                        href: 'https://github.com/Chidi09/Bloom',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'CLI Reference',
                      ),
                      A(
                        href: '/bloom',
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'UI Primitives',
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-3',
                    children: [
                      H4(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: 'AI & LLMs',
                      ),
                      A(
                        href: '/llms.txt',
                        attrs: const {'target': '_blank'},
                        className:
                            'block text-purple-600 dark:text-purple-400 '
                            'hover:underline font-mono text-xs font-semibold',
                        text: '/llms.txt (Index)',
                      ),
                      A(
                        href: '/llms-full.txt',
                        attrs: const {'target': '_blank'},
                        className:
                            'block text-purple-600 dark:text-purple-400 '
                            'hover:underline font-mono text-xs font-semibold',
                        text: '/llms-full.txt (Full)',
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-3',
                    children: [
                      H4(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: 'Community & Legal',
                      ),
                      A(
                        href: 'https://github.com/Chidi09/Bloom',
                        attrs: const {'target': '_blank'},
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'GitHub',
                      ),
                      A(
                        href: 'https://pub.dev/packages/bloom_js_native',
                        attrs: const {'target': '_blank'},
                        className:
                            'block text-slate-500 hover:text-purple-500 transition',
                        text: 'Pub.dev',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Bottom Legal Bar
          Div(
            className:
                'pt-8 border-t border-slate-200 dark:border-zinc-800 flex '
                'flex-col md:flex-row justify-between items-center gap-4 '
                'text-xs text-slate-500',
            children: [
              Div(
                className: 'flex items-center gap-4',
                children: [
                  P(
                    text: '© 2026 Bloom Platform Inc. Open source MIT License.',
                  ),
                ],
              ),
              Div(
                className:
                    'flex items-center gap-2 text-emerald-500 font-mono '
                    'font-semibold',
                children: [
                  Span(
                    className:
                        'w-2 h-2 rounded-full bg-emerald-500 animate-pulse',
                  ),
                  Span(text: 'All Systems Operational'),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
