import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final selectedRoute = signal('home');
final rolloutPct = signal(50);
final accentColor = signal('#8B5CF6');
final cardRadius = signal(12);

BloomNode chapterCards() {
  return Div(
    className: 'grid grid-cols-1 lg:grid-cols-3 gap-8 max-w-6xl mx-auto',
    children: [
      // CHAPTER 01: BUILD CARD
      Div(
        className:
            'group relative p-8 rounded-3xl bg-white dark:bg-black '
            'backdrop-blur border border-slate-200 '
            'dark:border-zinc-800 hover:border-purple-500/50 '
            'dark:hover:border-purple-400/50 hover:shadow-2xl '
            'transition-all duration-300 flex flex-col '
            'justify-between overflow-hidden',
        children: [
          Div(
            className:
                'absolute top-0 right-0 p-6 opacity-10 '
                'group-hover:opacity-20 transition-opacity '
                'text-purple-500',
            children: [hugeIcon('cpu', className: 'w-24 h-24')],
          ),
          Div(
            children: [
              Div(
                className: 'flex items-center justify-between mb-4',
                children: [
                  Span(
                    className:
                        'px-3 py-1 rounded-full bg-purple-500/10 text-purple-600 '
                        'dark:text-purple-400 text-xs font-mono font-bold border '
                        'border-purple-500/20',
                    text: 'CHAPTER 01',
                  ),
                  Span(
                    className:
                        'text-xs font-mono font-bold text-slate-500 '
                        'dark:text-slate-400',
                    text: 'FRAMEWORK',
                  ),
                ],
              ),
              H3(
                className:
                    'text-2xl font-black text-slate-900 dark:text-white mb-2 '
                    'tracking-tight',
                text: 'BUILD',
              ),
              P(
                className:
                    'text-xs sm:text-sm text-slate-600 dark:text-slate-400 '
                    'leading-relaxed mb-6 font-normal',
                children: [
                  const Text('Filesystem routing over '),
                  Code(
                    className:
                        'font-mono text-purple-600 dark:text-purple-400 font-bold',
                    text: 'go_router',
                  ),
                  const Text(', zero-boilerplate '),
                  Code(
                    className:
                        'font-mono text-purple-600 dark:text-purple-400 font-bold',
                    text: 'signals',
                  ),
                  const Text(' state API, and automated CLI code generators.'),
                ],
              ),

              // Interactive Micro-Demo: Route Previewer
              Div(
                className:
                    'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                    'text-slate-900 dark:text-white border border-slate-200 '
                    'dark:border-zinc-800 mb-6 font-mono text-xs space-y-3',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between pb-2 border-b '
                        'border-slate-200 dark:border-zinc-800 text-[10px] '
                        'text-slate-500 dark:text-slate-400',
                    children: [
                      Span(text: 'File-System Routes'),
                      Span(
                        className:
                            'text-purple-600 dark:text-purple-400 font-bold',
                        text: 'Generated AST',
                      ),
                    ],
                  ),
                  Div(
                    className: 'flex gap-1.5',
                    children: [
                      Live(
                        () => Button(
                          onClick: (_) => selectedRoute.value = 'home',
                          className:
                              'px-2 py-1 rounded text-[10px] transition-colors ${selectedRoute.value == 'home' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-200 dark:bg-zinc-800 text-slate-700 dark:text-slate-300 hover:bg-slate-300 dark:hover:bg-zinc-700'}',
                          text: 'index.dart',
                        ),
                      ),
                      Live(
                        () => Button(
                          onClick: (_) => selectedRoute.value = 'user',
                          className:
                              'px-2 py-1 rounded text-[10px] transition-colors ${selectedRoute.value == 'user' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-200 dark:bg-zinc-800 text-slate-700 dark:text-slate-300 hover:bg-slate-300 dark:hover:bg-zinc-700'}',
                          text: 'users/[id].dart',
                        ),
                      ),
                      Live(
                        () => Button(
                          onClick: (_) => selectedRoute.value = 'layout',
                          className:
                              'px-2 py-1 rounded text-[10px] transition-colors ${selectedRoute.value == 'layout' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-200 dark:bg-zinc-800 text-slate-700 dark:text-slate-300 hover:bg-slate-300 dark:hover:bg-zinc-700'}',
                          text: '_layout.dart',
                        ),
                      ),
                    ],
                  ),
                  Live(() {
                    final r = selectedRoute.value;
                    return Div(
                      className:
                          'text-[11px] text-slate-700 dark:text-slate-300 bg-white '
                          'dark:bg-zinc-900 p-2.5 rounded border border-slate-200 '
                          'dark:border-zinc-800',
                      children: [
                        if (r == 'home')
                          Span(
                            children: [
                              const Text('Route: '),
                              Strong(
                                className: 'text-teal-600 dark:text-teal-400',
                                text: "'/'",
                              ),
                              const Text(' → HomeView()'),
                            ],
                          )
                        else if (r == 'user')
                          Span(
                            children: [
                              const Text('Route: '),
                              Strong(
                                className: 'text-teal-600 dark:text-teal-400',
                                text: "'/users/:id'",
                              ),
                              const Text(' → UserView(id: String)'),
                            ],
                          )
                        else
                          Span(
                            children: [
                              const Text('Route: '),
                              Strong(
                                className: 'text-teal-600 dark:text-teal-400',
                                text: "'/_layout'",
                              ),
                              const Text(' → AppScaffold(child)'),
                            ],
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
          A(
            href: '/build',
            className:
                'inline-flex items-center justify-between w-full px-5 '
                'py-3 rounded-xl bg-slate-900 dark:bg-white text-white '
                'dark:text-slate-950 font-bold text-xs shadow-md '
                'hover:bg-slate-800 dark:hover:bg-slate-100 '
                'transition-all group/btn',
            children: [
              Span(text: 'Explore Framework Architecture'),
              hugeIcon(
                'arrow-right',
                className:
                    'w-4 h-4 group-hover/btn:translate-x-1 '
                    'transition-transform',
              ),
            ],
          ),
        ],
      ),

      // CHAPTER 02: SHIP CARD
      Div(
        className:
            'group relative p-8 rounded-3xl bg-white dark:bg-black '
            'backdrop-blur border border-slate-200 '
            'dark:border-zinc-800 hover:border-blue-500/50 '
            'dark:hover:border-blue-400/50 hover:shadow-2xl '
            'transition-all duration-300 flex flex-col '
            'justify-between overflow-hidden',
        children: [
          Div(
            className:
                'absolute top-0 right-0 p-6 opacity-10 '
                'group-hover:opacity-20 transition-opacity text-blue-500',
            children: [hugeIcon('rocket', className: 'w-24 h-24')],
          ),
          Div(
            children: [
              Div(
                className: 'flex items-center justify-between mb-4',
                children: [
                  Span(
                    className:
                        'px-3 py-1 rounded-full bg-blue-500/10 text-blue-600 '
                        'dark:text-blue-400 text-xs font-mono font-bold border '
                        'border-blue-500/20',
                    text: 'CHAPTER 02',
                  ),
                  Span(
                    className:
                        'text-xs font-mono font-bold text-slate-500 '
                        'dark:text-slate-400',
                    text: 'CLOUD OTA',
                  ),
                ],
              ),
              H3(
                className:
                    'text-2xl font-black text-slate-900 dark:text-white mb-2 '
                    'tracking-tight',
                text: 'SHIP',
              ),
              P(
                className:
                    'text-xs sm:text-sm text-slate-600 dark:text-slate-400 '
                    'leading-relaxed mb-6 font-normal',
                text:
                    'Integrated Shorebird over-the-air (OTA) updates, remote '
                    'build pipeline, and instant cryptographic byte-patching.',
              ),

              // Interactive Micro-Demo: OTA Rollout Simulator
              Div(
                className:
                    'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                    'text-slate-900 dark:text-white border border-slate-200 '
                    'dark:border-zinc-800 mb-6 font-mono text-xs space-y-3',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between pb-2 border-b '
                        'border-slate-200 dark:border-zinc-800 text-[10px] '
                        'text-slate-500 dark:text-slate-400',
                    children: [
                      Span(text: 'Staged Patch Rollout'),
                      Live(
                        () => Span(
                          className:
                              'text-blue-600 dark:text-blue-400 font-bold',
                          text: '${rolloutPct.value}% ACTIVE',
                        ),
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-1.5',
                    children: [
                      Input(
                        attrs: const {
                          'type': 'range',
                          'min': '0',
                          'max': '100',
                          'value': '50',
                        },
                        className:
                            'w-full accent-blue-500 cursor-pointer h-1.5 bg-slate-200 '
                            'dark:bg-zinc-800 rounded-lg',
                        onInput: (e) {
                          final v = int.tryParse(e.value ?? '');
                          if (v != null) rolloutPct.value = v;
                        },
                      ),
                      Div(
                        className:
                            'flex justify-between text-[9px] text-slate-400',
                        children: [
                          Span(text: 'Canary (1%)'),
                          Span(text: 'Staged (50%)'),
                          Span(text: 'Global (100%)'),
                        ],
                      ),
                    ],
                  ),
                  Live(() {
                    final pct = rolloutPct.value;
                    return Div(
                      className:
                          'text-[11px] flex items-center justify-between bg-white '
                          'dark:bg-zinc-900 p-2.5 rounded border border-slate-200 '
                          'dark:border-zinc-800',
                      children: [
                        Span(
                          className: 'text-slate-600 dark:text-slate-400',
                          text: 'Release: v1.0.4+42',
                        ),
                        Span(
                          className: pct == 100
                              ? 'text-emerald-500 font-bold'
                              : 'text-blue-500 font-bold',
                          text: pct == 100
                              ? 'Fully Deployed'
                              : '$pct% Promoted',
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
          A(
            href: '/ship',
            className:
                'inline-flex items-center justify-between w-full px-5 '
                'py-3 rounded-xl bg-slate-900 dark:bg-white text-white '
                'dark:text-slate-950 font-bold text-xs shadow-md '
                'hover:bg-slate-800 dark:hover:bg-slate-100 '
                'transition-all group/btn',
            children: [
              Span(text: 'Explore Cloud OTA Pipeline'),
              hugeIcon(
                'arrow-right',
                className:
                    'w-4 h-4 group-hover/btn:translate-x-1 '
                    'transition-transform',
              ),
            ],
          ),
        ],
      ),

      // CHAPTER 03: BLOOM CARD
      Div(
        className:
            'group relative p-8 rounded-3xl bg-white dark:bg-black '
            'backdrop-blur border border-slate-200 '
            'dark:border-zinc-800 hover:border-pink-500/50 '
            'dark:hover:border-pink-400/50 hover:shadow-2xl '
            'transition-all duration-300 flex flex-col '
            'justify-between overflow-hidden',
        children: [
          Div(
            className:
                'absolute top-0 right-0 p-6 opacity-10 '
                'group-hover:opacity-20 transition-opacity text-pink-500',
            children: [hugeIcon('zap', className: 'w-24 h-24')],
          ),
          Div(
            children: [
              Div(
                className: 'flex items-center justify-between mb-4',
                children: [
                  Span(
                    className:
                        'px-3 py-1 rounded-full bg-pink-500/10 text-pink-600 '
                        'dark:text-pink-400 text-xs font-mono font-bold border '
                        'border-pink-500/20',
                    text: 'CHAPTER 03',
                  ),
                  Span(
                    className:
                        'text-xs font-mono font-bold text-slate-500 '
                        'dark:text-slate-400',
                    text: 'UI STUDIO',
                  ),
                ],
              ),
              H3(
                className:
                    'text-2xl font-black text-slate-900 dark:text-white mb-2 '
                    'tracking-tight',
                text: 'BLOOM',
              ),
              P(
                className:
                    'text-xs sm:text-sm text-slate-600 dark:text-slate-400 '
                    'leading-relaxed mb-6 font-normal',
                children: [
                  const Text('60+ '),
                  Code(
                    className:
                        'font-mono text-pink-600 dark:text-pink-400 font-bold',
                    text: 'shadcn/ui',
                  ),
                  const Text(
                    '-inspired composable Flutter widgets, live token customizers, and responsive primitives.',
                  ),
                ],
              ),

              // Interactive Micro-Demo: Theme Customizer
              Div(
                className:
                    'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                    'text-slate-900 dark:text-white border border-slate-200 '
                    'dark:border-zinc-800 mb-6 font-mono text-xs space-y-3',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between pb-2 border-b '
                        'border-slate-200 dark:border-zinc-800 text-[10px] '
                        'text-slate-500 dark:text-slate-400',
                    children: [
                      Span(text: 'Live Token Customizer'),
                      Span(
                        className: 'text-pink-600 dark:text-pink-400 font-bold',
                        text: 'Reactive UI',
                      ),
                    ],
                  ),
                  Div(
                    className: 'flex items-center justify-between gap-2',
                    children: [
                      Div(
                        className: 'flex gap-1.5',
                        children: [
                          for (final color in [
                            '#8B5CF6',
                            '#3B82F6',
                            '#EC4899',
                            '#10B981',
                          ])
                            Button(
                              onClick: (_) => accentColor.value = color,
                              style: 'background-color: $color;',
                              className:
                                  'w-5 h-5 rounded-full border-2 border-white '
                                  'dark:border-black shadow-sm transition-transform '
                                  'active:scale-90',
                            ),
                        ],
                      ),
                      Input(
                        attrs: const {
                          'type': 'range',
                          'min': '0',
                          'max': '24',
                          'value': '12',
                        },
                        className:
                            'w-20 accent-pink-500 cursor-pointer h-1.5 bg-slate-200 '
                            'dark:bg-zinc-800 rounded-lg',
                        onInput: (e) {
                          final v = int.tryParse(e.value ?? '');
                          if (v != null) cardRadius.value = v;
                        },
                      ),
                    ],
                  ),
                  Live(() {
                    final color = accentColor.value;
                    final rad = cardRadius.value;
                    return Div(
                      className: 'p-2.5 rounded flex justify-center',
                      children: [
                        Button(
                          style:
                              'background-color: $color; border-radius: ${rad}px;',
                          className:
                              'px-4 py-1.5 text-white font-bold text-[11px] shadow-sm '
                              'transition-all',
                          text: 'BloomButton.primary()',
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
          A(
            href: '/bloom',
            className:
                'inline-flex items-center justify-between w-full px-5 '
                'py-3 rounded-xl bg-slate-900 dark:bg-white text-white '
                'dark:text-slate-950 font-bold text-xs shadow-md '
                'hover:bg-slate-800 dark:hover:bg-slate-100 '
                'transition-all group/btn',
            children: [
              Span(text: 'Launch Mobile UI Studio'),
              hugeIcon(
                'arrow-right',
                className:
                    'w-4 h-4 group-hover/btn:translate-x-1 '
                    'transition-transform',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
