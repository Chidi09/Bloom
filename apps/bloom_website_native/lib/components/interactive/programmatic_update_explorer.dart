import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

BloomNode programmaticUpdateExplorer() {
  final step = signal('IDLE');
  final downloadProgress = signal(0);

  return Div(
    className:
        'p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl '
        'mx-auto space-y-8 text-left',
    children: [
      // Header & Controls
      Div(
        className:
            'flex flex-col sm:flex-row sm:items-center justify-between gap-4 '
            'pb-6 border-b border-slate-200 dark:border-zinc-800',
        children: [
          Div(
            children: [
              Div(
                className: 'flex items-center gap-2 mb-1',
                children: [
                  hugeIcon(
                    'zap',
                    className: 'w-5 h-5 text-purple-600 dark:text-purple-400',
                  ),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Interactive Programmatic BloomCloud API Inspector',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Click run to test silent background download, progress hooks, '
                    'and hot app restart.',
              ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              Live(() {
                final current = step.value;
                final isRunning =
                    current == 'CHECKING' || current == 'DOWNLOADING';

                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) {
                    step.value = 'CHECKING';
                    downloadProgress.value = 0;

                    Timer(const Duration(milliseconds: 600), () {
                      step.value = 'FOUND';
                      Timer(const Duration(milliseconds: 600), () {
                        step.value = 'DOWNLOADING';
                        int prog = 0;
                        Timer.periodic(const Duration(milliseconds: 200), (
                          timer,
                        ) {
                          prog += 25;
                          downloadProgress.value = prog;
                          if (prog >= 100) {
                            timer.cancel();
                            step.value = 'DOWNLOADED';
                          }
                        });
                      });
                    });
                  },
                  className:
                      'px-4 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white '
                      'dark:text-slate-950 font-black text-xs shadow-md '
                      'hover:bg-slate-800 dark:hover:bg-slate-200 transition-all '
                      'active:scale-95 cursor-pointer ${current != 'IDLE' ? 'opacity-50 pointer-events-none' : ''}',
                  children: [
                    hugeIcon(
                      isRunning ? 'refresh' : 'sparkles',
                      className: 'w-3.5 h-3.5',
                    ),
                    Text(isRunning ? ' Running...' : ' Execute Update Flow'),
                  ],
                );
              }),
              Live(() {
                if (step.value == 'DOWNLOADED') {
                  return Button(
                    attrs: {'type': 'button'},
                    onClick: (_) {
                      step.value = 'APPLIED';
                      Timer(const Duration(seconds: 2), () {
                        step.value = 'IDLE';
                      });
                    },
                    className:
                        'px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 '
                        'text-white font-black text-xs shadow-md animate-bounce '
                        'transition-all cursor-pointer',
                    text: 'Restart App (Apply Patch)',
                  );
                }
                return Span();
              }),
            ],
          ),
        ],
      ),

      // Grid: Code vs State Simulation
      Div(
        className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch',
        children: [
          // Left: Dart API Code
          Div(
            className: 'lg:col-span-6 space-y-3',
            children: [
              Div(
                className:
                    'flex items-center justify-between text-xs font-mono '
                    'text-slate-500 dark:text-slate-400',
                children: [
                  Span(
                    className: 'font-bold text-slate-900 dark:text-white',
                    text: 'lib / services / update_service.dart',
                  ),
                  Span(
                    className:
                        'text-purple-600 dark:text-purple-400 font-bold '
                        'text-[10px]',
                    text: 'CLIENT_SDK',
                  ),
                ],
              ),
              Div(
                className:
                    'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                    'border border-slate-800 dark:border-zinc-800 font-mono text-xs '
                    'shadow-xl',
                children: [
                  Pre(
                    className:
                        'p-4 sm:p-5 leading-relaxed overflow-x-auto '
                        'text-slate-200',
                    children: [
                      Code(
                        className: 'language-dart',
                        text: '''// Programmatic OTA download & restart
final ota = BloomCloud.instance;
final update = await ota.checkForUpdate();

if (update.isAvailable) {
  await ota.downloadUpdate(
    onProgress: (p) => progress.value = p,
  );
  await ota.applyAndRestart();
}''',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Right: State Machine Visualizer
          Div(
            className:
                'lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                'border border-slate-200 dark:border-zinc-800 flex flex-col '
                'justify-between font-mono text-xs space-y-6',
            children: [
              Div(
                className: 'space-y-4',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between pb-2 border-b '
                        'border-slate-200 dark:border-zinc-800 text-slate-500 '
                        'dark:text-slate-400',
                    children: [
                      Span(text: 'Runtime State Machine'),
                      Live(() {
                        return Span(
                          className:
                              'text-purple-600 dark:text-purple-400 font-bold',
                          text: step.value,
                        );
                      }),
                    ],
                  ),
                  Live(() {
                    final current = step.value;
                    return Div(
                      className: 'space-y-2',
                      children: [
                        for (final s in [
                          (
                            '1. Check for Patch',
                            current == 'CHECKING' ||
                                current == 'FOUND' ||
                                current == 'DOWNLOADING' ||
                                current == 'DOWNLOADED' ||
                                current == 'APPLIED',
                          ),
                          (
                            '2. Hash Verified (SHA-256)',
                            current == 'FOUND' ||
                                current == 'DOWNLOADING' ||
                                current == 'DOWNLOADED' ||
                                current == 'APPLIED',
                          ),
                          (
                            '3. Background Download',
                            current == 'DOWNLOADING' ||
                                current == 'DOWNLOADED' ||
                                current == 'APPLIED',
                          ),
                          (
                            '4. Hot Apply & Isolate Restart',
                            current == 'APPLIED',
                          ),
                        ])
                          Div(
                            className:
                                'p-2.5 rounded-xl border flex items-center justify-between ${s.$2 ? 'bg-white dark:bg-zinc-900 border-purple-500/30 text-purple-600 dark:text-purple-400 font-bold' : 'bg-transparent border-slate-200 dark:border-zinc-800/60 text-slate-400 opacity-60'}',
                            children: [
                              Span(text: s.$1),
                              Span(text: s.$2 ? '✓' : '•'),
                            ],
                          ),
                      ],
                    );
                  }),
                ],
              ),
              Live(() {
                final prog = downloadProgress.value;
                return Div(
                  className: 'space-y-2',
                  children: [
                    Div(
                      className:
                          'flex items-center justify-between text-[11px] font-bold '
                          'text-slate-600 dark:text-slate-400',
                      children: [
                        Span(text: 'Background Stream Download'),
                        Span(text: '$prog%'),
                      ],
                    ),
                    Div(
                      className:
                          'w-full h-2 bg-slate-200 dark:bg-zinc-800 rounded-full '
                          'overflow-hidden',
                      children: [
                        Div(
                          className:
                              'h-full bg-emerald-500 rounded-full transition-all '
                              'duration-200',
                          style: 'width: $prog%;',
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
    ],
  );
}
