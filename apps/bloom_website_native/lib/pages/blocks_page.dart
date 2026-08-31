import 'package:bloom_js_native/bloom_js_native.dart'
    hide showToast; // local site toast system takes precedence
import '../components/huge_icons.dart';
import '../components/toast_system.dart';
import '../data/blocks_data.dart';
import 'page_layout.dart';

BloomNode blocksPage() {
  final activeCategory = signal('all');
  final activeViewMode = signal('preview'); // 'preview' or 'code'

  return pageLayout(
    currentPath: '/blocks',
    petalHighlight: 'purple',
    nextChapterTitle: 'BLOOM — UI Studio & Tokens',
    nextChapterLink: '/bloom',
    nextChapterSubtitle:
        'Explore 60+ shadcn-inspired composable primitives with '
        'live token controls.',
    child: Div(
      className:
          'relative space-y-16 pb-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8',
      children: [
        // 1. Hero Section
        Section(
          className: 'pt-12 pb-8 text-center space-y-4',
          children: [
            Div(
              className:
                  'inline-flex items-center gap-2.5 px-3.5 py-1.5 '
                  'rounded-full bg-slate-900/90 dark:bg-black/90 border '
                  'border-slate-700/60 dark:border-zinc-800 text-xs font-mono '
                  'text-slate-300 shadow-md',
              children: [
                Span(
                  className: 'flex h-2 w-2 relative shrink-0',
                  children: [
                    Span(
                      className:
                          'animate-ping absolute inline-flex h-full w-full '
                          'rounded-full bg-purple-400 opacity-75',
                    ),
                    Span(
                      className:
                          'relative inline-flex rounded-full h-2 w-2 bg-purple-500',
                    ),
                  ],
                ),
                Span(
                  className: 'font-semibold text-slate-200',
                  text: 'APPLICATION BLOCKS',
                ),
                Span(
                  className: 'text-slate-600 dark:text-slate-500',
                  text: '•',
                ),
                Span(
                  className: 'text-purple-400 font-mono',
                  text: 'READY_TO_SHIP_SCREENS',
                ),
              ],
            ),
            H1(
              className:
                  'text-4xl sm:text-6xl font-black tracking-tight '
                  'text-slate-900 dark:text-white',
              children: [
                const Text('Application Blocks.'),
                El('br'),
                Span(
                  className: 'text-gradient-silver',
                  text: 'Production-Ready Screens & Sections.',
                ),
              ],
            ),
            P(
              className:
                  'text-slate-600 dark:text-slate-400 text-base sm:text-lg '
                  'max-w-2xl mx-auto leading-relaxed',
              text:
                  'Fully assembled dashboard, authentication, chat, and settings '
                  'screens built with Bloom UI primitives. Copy the Flutter source code '
                  'directly into your apps.',
            ),
          ],
        ),

        // 2. Filter & Navigation Bar
        Div(
          className:
              'flex flex-wrap items-center justify-between gap-4 pb-6 border-b '
              'border-slate-200 dark:border-zinc-800',
          children: [
            // Category Buttons
            Div(
              className: 'flex flex-wrap gap-2',
              children: [
                for (final cat in [
                  ('all', 'All Screens'),
                  ('Dashboard', 'Dashboards'),
                  ('Auth', 'Authentication'),
                  ('Chat', 'Chat & Messaging'),
                  ('Settings', 'Settings & Admin'),
                ])
                  Live(() {
                    final isSelected = activeCategory.value == cat.$1;
                    return Button(
                      onClick: (_) => activeCategory.value = cat.$1,
                      className:
                          'px-4 py-2 rounded-xl text-xs font-mono font-bold transition-all border cursor-pointer ${isSelected ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md scale-105' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'}',
                      text: cat.$2,
                    );
                  }),
              ],
            ),

            // View Toggle (Preview / Code)
            Live(() {
              final isPreview = activeViewMode.value == 'preview';
              return Div(
                className:
                    'p-1 bg-slate-100 dark:bg-zinc-900 rounded-xl border '
                    'border-slate-200 dark:border-zinc-800 flex items-center gap-1 font-mono text-xs',
                children: [
                  Button(
                    onClick: (_) => activeViewMode.value = 'preview',
                    className:
                        'px-3 py-1.5 rounded-lg transition-all cursor-pointer ${isPreview ? 'bg-white dark:bg-black text-slate-900 dark:text-white font-bold shadow' : 'text-slate-500 hover:text-slate-900 dark:hover:text-white'}',
                    text: 'Interactive Preview',
                  ),
                  Button(
                    onClick: (_) => activeViewMode.value = 'code',
                    className:
                        'px-3 py-1.5 rounded-lg transition-all cursor-pointer ${!isPreview ? 'bg-white dark:bg-black text-slate-900 dark:text-white font-bold shadow' : 'text-slate-500 hover:text-slate-900 dark:hover:text-white'}',
                    text: 'Flutter Code',
                  ),
                ],
              );
            }),
          ],
        ),

        // 3. Blocks Grid & Detail Canvas
        Div(
          className: 'space-y-12',
          children: [
            for (final block in blocksData)
              Live(() {
                final cat = activeCategory.value;
                if (cat != 'all' && block.category != cat) {
                  return Div();
                }

                final isCodeView = activeViewMode.value == 'code';

                return Div(
                  attrs: {'id': block.id},
                  className:
                      'p-6 sm:p-8 rounded-3xl bg-white dark:bg-black backdrop-blur '
                      'border border-slate-200 dark:border-zinc-800 shadow-2xl space-y-6 text-left',
                  children: [
                    // Card Header
                    Div(
                      className:
                          'flex flex-col sm:flex-row sm:items-center '
                          'justify-between gap-4 pb-4 border-b border-slate-100 '
                          'dark:border-zinc-900',
                      children: [
                        Div(
                          className: 'space-y-1',
                          children: [
                            Div(
                              className: 'flex items-center gap-2',
                              children: [
                                Span(
                                  className:
                                      'px-2 py-0.5 rounded text-[10px] font-mono '
                                      'font-bold bg-purple-500/10 text-purple-600 '
                                      'dark:text-purple-400 border border-purple-500/20',
                                  text: block.category.toUpperCase(),
                                ),
                                Span(
                                  className: 'text-xs font-mono text-slate-400',
                                  text: block.id,
                                ),
                              ],
                            ),
                            H3(
                              className:
                                  'text-xl font-bold text-slate-900 dark:text-white '
                                  'tracking-tight',
                              text: block.title,
                            ),
                            P(
                              className:
                                  'text-xs text-slate-600 dark:text-slate-400 max-w-xl',
                              text: block.description,
                            ),
                          ],
                        ),

                        // Action Buttons
                        Div(
                          className: 'flex items-center gap-2 shrink-0',
                          children: [
                            Button(
                              attrs: {
                                'type': 'button',
                                'onclick':
                                    "navigator.clipboard.writeText(`${block.flutterCode.replaceAll('`', r'\`').replaceAll(r'$', r'\$')}`); window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Code Copied', message: 'Copied ${block.title} Flutter source.', type: 'emerald' } }));",
                              },
                              className:
                                  'px-4 py-2 rounded-xl bg-slate-900 dark:bg-white text-white '
                                  'dark:text-slate-950 font-bold text-xs shadow-md '
                                  'hover:bg-slate-800 dark:hover:bg-slate-200 transition-all '
                                  'cursor-pointer flex items-center gap-1.5',
                              children: [
                                hugeIcon('code', className: 'w-3.5 h-3.5'),
                                const Text('Copy Flutter Code'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Card Content Body: Preview or Code
                    if (!isCodeView)
                      Div(
                        className:
                            'p-6 sm:p-10 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                            'border border-slate-200 dark:border-zinc-800 min-h-[280px] '
                            'flex items-center justify-center relative overflow-hidden',
                        children: [_renderBlockPreview(block.id)],
                      )
                    else
                      Div(
                        className:
                            'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                            'border border-slate-800 dark:border-zinc-800 font-mono text-xs shadow-xl',
                        children: [
                          Pre(
                            className:
                                'p-5 sm:p-6 leading-relaxed overflow-x-auto '
                                'text-purple-300',
                            children: [Code(text: block.flutterCode)],
                          ),
                        ],
                      ),
                  ],
                );
              }),
          ],
        ),
      ],
    ),
  );
}

BloomNode _renderBlockPreview(String blockId) {
  if (blockId == 'dashboard-01') {
    return Div(
      className: 'w-full max-w-2xl space-y-4',
      children: [
        Div(
          className: 'grid grid-cols-2 gap-4',
          children: [
            Div(
              className:
                  'p-4 rounded-xl bg-white dark:bg-zinc-950 border '
                  'border-slate-200 dark:border-zinc-800 space-y-1 shadow-sm',
              children: [
                Div(
                  className: 'text-[11px] text-slate-500 dark:text-slate-400',
                  text: 'Total Revenue',
                ),
                Div(
                  className: 'text-xl font-bold text-slate-900 dark:text-white',
                  text: r'$45,231.89',
                ),
                Div(
                  className:
                      'text-[10px] text-emerald-600 dark:text-emerald-400 '
                      'font-mono font-bold',
                  text: '+20.1% vs last mo',
                ),
              ],
            ),
            Div(
              className:
                  'p-4 rounded-xl bg-white dark:bg-zinc-950 border '
                  'border-slate-200 dark:border-zinc-800 space-y-1 shadow-sm',
              children: [
                Div(
                  className: 'text-[11px] text-slate-500 dark:text-slate-400',
                  text: 'Active Subscriptions',
                ),
                Div(
                  className: 'text-xl font-bold text-slate-900 dark:text-white',
                  text: '+2,350',
                ),
                Div(
                  className:
                      'text-[10px] text-purple-600 dark:text-purple-400 '
                      'font-mono font-bold',
                  text: '+180 new today',
                ),
              ],
            ),
          ],
        ),
        Div(
          className:
              'p-4 rounded-xl bg-white dark:bg-zinc-950 border '
              'border-slate-200 dark:border-zinc-800 space-y-2 shadow-sm',
          children: [
            Div(
              className: 'text-xs font-bold text-slate-900 dark:text-white',
              text: 'Monthly Transaction Trend',
            ),
            Div(
              className: 'h-28 flex items-end gap-2 pt-2',
              children: [
                for (final v in [30, 45, 65, 80, 50, 95, 110])
                  Div(
                    className:
                        'flex-1 bg-gradient-to-t from-purple-600 to-pink-500 '
                        'rounded-t',
                    style: 'height: ${v * 0.85}%;',
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  if (blockId == 'auth-01') {
    return Div(
      className:
          'w-full max-w-sm p-6 rounded-2xl bg-white dark:bg-zinc-950 '
          'border border-slate-200 dark:border-zinc-800 space-y-4 shadow-xl',
      children: [
        Div(
          className: 'space-y-1',
          children: [
            Div(
              className: 'text-base font-bold text-slate-900 dark:text-white',
              text: 'Welcome Back',
            ),
            Div(
              className: 'text-xs text-slate-500 dark:text-slate-400',
              text: 'Sign in to manage your Flutter deployments.',
            ),
          ],
        ),
        Div(
          className: 'space-y-2',
          children: [
            Input(
              attrs: {
                'type': 'email',
                'placeholder': 'name@example.com',
                'value': '',
              },
              className:
                  'w-full p-2.5 rounded-xl bg-slate-50 dark:bg-black border '
                  'border-slate-200 dark:border-zinc-800 text-xs text-slate-900 '
                  'dark:text-white',
            ),
            Input(
              attrs: {
                'type': 'password',
                'placeholder': '••••••••••••',
                'value': '',
              },
              className:
                  'w-full p-2.5 rounded-xl bg-slate-50 dark:bg-black border '
                  'border-slate-200 dark:border-zinc-800 text-xs text-slate-900 '
                  'dark:text-white',
            ),
          ],
        ),
        Button(
          attrs: const {'type': 'button'},
          onClick: (_) => showToast(
            'Demo Preview',
            'This auth block is an illustrative Flutter component preview — '
                'copy its source code into your app instead.',
            type: 'blue',
          ),
          className:
              'w-full py-2.5 rounded-xl bg-purple-600 text-white font-bold '
              'text-xs shadow hover:bg-purple-500 transition cursor-pointer',
          text: 'Sign In with Email',
        ),
      ],
    );
  }

  if (blockId == 'chat-01') {
    return Div(
      className:
          'w-full max-w-md p-4 rounded-2xl bg-white dark:bg-zinc-950 '
          'border border-slate-200 dark:border-zinc-800 space-y-4 shadow-xl',
      children: [
        Div(
          className:
              'flex items-center gap-2 border-b border-slate-200 '
              'dark:border-zinc-800 pb-2',
          children: [
            Div(
              className:
                  'w-6 h-6 rounded-full bg-purple-600 flex items-center '
                  'justify-center text-[10px] font-bold text-white',
              text: 'AI',
            ),
            Div(
              className: 'text-xs font-bold text-slate-900 dark:text-white',
              text: 'Bloom Assistant',
            ),
          ],
        ),
        Div(
          className: 'space-y-3 text-xs',
          children: [
            Div(
              className:
                  'p-3 rounded-xl bg-slate-100 dark:bg-zinc-900 '
                  'text-slate-800 dark:text-slate-200 self-start max-w-[80%]',
              text:
                  'Hello! How can I assist with your Flutter app layout today?',
            ),
            Div(
              className:
                  'p-3 rounded-xl bg-purple-600 text-white self-end ml-auto '
                  'max-w-[80%]',
              text: 'Can you generate a responsive data table?',
            ),
          ],
        ),
      ],
    );
  }

  if (blockId == 'settings-01') {
    return Div(
      className:
          'w-full max-w-md p-5 rounded-2xl bg-white dark:bg-zinc-950 '
          'border border-slate-200 dark:border-zinc-800 space-y-4 shadow-xl',
      children: [
        Div(
          className: 'text-sm font-bold text-slate-900 dark:text-white',
          text: 'System Settings',
        ),
        Div(
          className: 'space-y-3 text-xs',
          children: [
            Div(
              className:
                  'flex items-center justify-between p-2 rounded-lg bg-slate-50 '
                  'dark:bg-black border border-slate-200 dark:border-zinc-800',
              children: [
                Span(
                  className: 'text-slate-700 dark:text-slate-300 font-medium',
                  text: 'Dark Mode Sync',
                ),
                Span(
                  className:
                      'text-purple-600 dark:text-purple-400 font-mono font-bold',
                  text: 'Enabled',
                ),
              ],
            ),
            Div(
              className:
                  'flex items-center justify-between p-2 rounded-lg bg-slate-50 '
                  'dark:bg-black border border-slate-200 dark:border-zinc-800',
              children: [
                Span(
                  className: 'text-slate-700 dark:text-slate-300 font-medium',
                  text: 'OTA Push Notifications',
                ),
                Span(
                  className:
                      'text-purple-600 dark:text-purple-400 font-mono font-bold',
                  text: 'Active',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  return Div(text: 'Preview');
}
