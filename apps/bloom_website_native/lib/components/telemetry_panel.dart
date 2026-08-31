import 'package:bloom_js_native/bloom_js_native.dart';
import 'ui.dart';

BloomNode telemetryPanel() {
  final metrics = const [
    (
      'SSR TTFB',
      '<0.4ms',
      'Pure Dart AST to HTML string serialization with zero headless browser overhead.',
    ),
    (
      'JS Baseline',
      '0 kB',
      'Static SSG marketing content ships 0kB mandatory runtime for instant first paint.',
    ),
    (
      'Signal Patch',
      '0.02ms',
      'Direct DOM text node mutation bypassing virtual DOM tree diffing entirely.',
    ),
    (
      'Throughput',
      '50k/s',
      'Sustained signal mutations per second at 120 FPS without frame drops.',
    ),
  ];

  final nodes = const [
    (1, 98, '0.01ms'),
    (2, 94, '0.02ms'),
    (3, 99, '0.01ms'),
    (4, 91, '0.03ms'),
    (5, 96, '0.02ms'),
    (6, 100, '0.01ms'),
    (7, 95, '0.02ms'),
    (8, 97, '0.01ms'),
    (9, 93, '0.02ms'),
    (10, 99, '0.01ms'),
    (11, 92, '0.03ms'),
    (12, 98, '0.01ms'),
  ];

  return Section(
    attrs: const {'id': 'benchmark'},
    className: 'py-20 px-6 max-w-7xl mx-auto w-full',
    children: [
      // Section Title
      siteSectionHeader(
        eyebrow: 'Performance & Architecture',
        eyebrowIcon: 'activity',
        title: 'Fine-Grained Signals vs VDOM Diffing',
        description:
            'Unlike React or Flutter which recreate virtual element '
            'trees on every state change, Bloom binds signals '
            'directly to individual DOM text nodes and attributes '
            'with zero reconciliation overhead.',
      ),

      // Live Telemetry Card
      siteCard(
        className:
            'mb-12 border border-[#1E1E24] shadow-2xl relative overflow-hidden',
        children: [
          // Top Controls Bar
          Div(
            className:
                'flex flex-col md:flex-row md:items-center '
                'justify-between gap-6 pb-6 border-b border-[#1E1E24]',
            children: [
              // Left: Status
              Div(
                className: 'flex items-center gap-3',
                children: [
                  Div(
                    className:
                        'w-3 h-3 rounded-full bg-emerald-500 animate-pulse',
                  ),
                  Span(
                    className: 'text-sm font-semibold text-white',
                    text: 'Live Reactive Dispatcher Active',
                  ),
                  siteBadge(label: 'Fine-Grained AST', variant: 'brand'),
                ],
              ),

              // Right: Stats Ticker
              Div(
                className:
                    'flex items-center gap-6 font-mono text-xs flex-wrap',
                children: [
                  Div(
                    className: 'flex items-center gap-2',
                    children: [
                      Span(className: 'text-zinc-500', text: 'FPS:'),
                      Span(
                        className: 'text-emerald-400 font-bold',
                        text: '120.0',
                      ),
                    ],
                  ),
                  Div(
                    className: 'flex items-center gap-2',
                    children: [
                      Span(className: 'text-zinc-500', text: 'Patch Latency:'),
                      Span(
                        className: 'text-indigo-400 font-bold',
                        text: '0.02 ms',
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'flex items-center gap-2 bg-[#14141A] px-3 py-1.5 '
                        'rounded-lg border border-[#27272A]',
                    children: [
                      Span(className: 'text-zinc-500', text: 'Overhead:'),
                      Span(
                        className: 'text-cyan-400 font-bold',
                        text: '0% VDOM Diff',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Reactive Node Stress Grid
          Div(
            className: 'pt-6',
            children: [
              Div(
                className:
                    'grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 '
                    'lg:grid-cols-12 gap-2.5',
                children: [
                  for (final (id, metric, latency) in nodes)
                    Div(
                      className:
                          'p-3 rounded-xl bg-[#14141A] border border-[#27272A] '
                          'hover:border-indigo-500/50 flex flex-col justify-between '
                          'transition-colors shadow-sm',
                      children: [
                        Div(
                          className:
                              'flex items-center justify-between text-[10px] font-mono '
                              'text-zinc-500 mb-1',
                          children: [
                            Span(text: '#$id'),
                            Span(className: 'text-zinc-400', text: '$metric%'),
                          ],
                        ),
                        Span(
                          className:
                              'text-xs font-mono font-extrabold text-indigo-400 my-0.5 '
                              'tracking-tight',
                          text: latency,
                        ),
                        Div(
                          className:
                              'w-full h-1 bg-[#1E1E24] rounded-full overflow-hidden '
                              'mt-1.5',
                          children: [
                            Div(
                              className:
                                  'h-full bg-gradient-to-r from-indigo-500 to-violet-500 '
                                  'rounded-full',
                              style: 'width: $metric%;',
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),

      // 4 Metric Highlight Cards
      Div(
        className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6',
        children: [
          for (final (title, val, desc) in metrics)
            siteCard(
              children: [
                Span(
                  className:
                      'text-xs font-mono text-indigo-400 font-semibold '
                      'uppercase tracking-wider',
                  text: title,
                ),
                H3(
                  className:
                      'text-3xl font-extrabold text-white mt-2 mb-3 '
                      'tracking-tight',
                  text: val,
                ),
                P(
                  className: 'text-zinc-400 text-xs leading-relaxed',
                  text: desc,
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
