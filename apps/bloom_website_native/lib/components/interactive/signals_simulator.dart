import 'dart:math';

import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final _rng = Random();

final simCount = signal(5);
final simRebuildCount = signal(1);
final simRebuildTime = signal('0.20ms');

BloomNode signalsReactivitySimulator() {
  return Div(
    className:
        'p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black '
        'backdrop-blur border border-slate-200 '
        'dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto '
        'space-y-8',
    children: [
      Div(
        className:
            'flex flex-col sm:flex-row sm:items-center '
            'justify-between gap-4 pb-6 border-b border-slate-200 '
            'dark:border-zinc-800',
        children: [
          Div(
            children: [
              Div(
                className: 'flex items-center gap-2 mb-1',
                children: [
                  hugeIcon(
                    'refresh',
                    className: 'w-5 h-5 text-teal-600 dark:text-teal-400',
                  ),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Live 60FPS Signals Reactivity Simulator',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Click to update signal state and observe sub-millisecond '
                    'targeted widget rebuilds.',
              ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              Button(
                onClick: (_) {
                  simCount.value++;
                  simRebuildCount.value++;
                  simRebuildTime.value =
                      '${(_rng.nextDouble() * 0.3 + 0.1).toStringAsFixed(2)}ms';
                },
                className:
                    'px-4 py-2.5 rounded-xl bg-teal-600 hover:bg-teal-500 '
                    'text-white font-bold text-xs shadow-md '
                    'shadow-teal-500/20 transition-all active:scale-95',
                text: '+ Increment Signal',
              ),
              Button(
                onClick: (_) {
                  simCount.value = 0;
                  simRebuildCount.value++;
                },
                className:
                    'px-3 py-2.5 rounded-xl bg-slate-100 dark:bg-zinc-900 '
                    'border border-slate-200 dark:border-zinc-800 '
                    'text-slate-700 dark:text-slate-300 font-bold text-xs '
                    'hover:bg-slate-200 dark:hover:bg-zinc-800 transition-all',
                text: 'Reset',
              ),
            ],
          ),
        ],
      ),

      // Grid: Signal State vs Target Widget
      Div(
        className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch',
        children: [
          // Left: Signals Controller State
          Div(
            className:
                'lg:col-span-6 p-6 rounded-2xl bg-slate-50 '
                'dark:bg-zinc-950 text-slate-900 dark:text-white border '
                'border-slate-200 dark:border-zinc-800 font-mono text-xs '
                'space-y-4',
            children: [
              Div(
                className:
                    'flex items-center justify-between text-[11px] '
                    'text-slate-500 dark:text-slate-400 pb-2 border-b '
                    'border-slate-200 dark:border-zinc-800',
                children: [
                  Span(text: 'CounterController (Signal Memory)'),
                  Live(
                    () => Span(
                      className: 'text-teal-600 dark:text-teal-400 font-bold',
                      text: 'REBUILD_TIME: ${simRebuildTime.value}',
                    ),
                  ),
                ],
              ),
              Div(
                className: 'space-y-3',
                children: [
                  Div(
                    className:
                        'p-3 rounded-xl bg-white dark:bg-zinc-900 border '
                        'border-slate-200 dark:border-zinc-800 flex items-center '
                        'justify-between',
                    children: [
                      Live(
                        () => Span(
                          className: 'text-slate-600 dark:text-slate-400',
                          text: 'final count = signal(${simCount.value});',
                        ),
                      ),
                      Live(
                        () => Span(
                          className:
                              'text-teal-600 dark:text-teal-400 font-bold text-sm',
                          text: '${simCount.value}',
                        ),
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'p-3 rounded-xl bg-white dark:bg-zinc-900 border '
                        'border-slate-200 dark:border-zinc-800 flex items-center '
                        'justify-between',
                    children: [
                      Span(
                        className: 'text-slate-600 dark:text-slate-400',
                        text: 'computed(() => count % 2 == 0)',
                      ),
                      Live(() {
                        final isEven = simCount.value % 2 == 0;
                        return Span(
                          className:
                              'font-bold ${isEven ? 'text-emerald-600 dark:text-emerald-400' : 'text-amber-600 dark:text-amber-400'}',
                          text: isEven ? 'TRUE (Even)' : 'FALSE (Odd)',
                        );
                      }),
                    ],
                  ),
                ],
              ),
              Div(
                className:
                    'text-[11px] text-slate-500 pt-2 border-t '
                    'border-slate-200 dark:border-zinc-800',
                children: [
                  const Text('Total Widget Rebuilds Triggered: '),
                  Live(
                    () => Strong(
                      className: 'text-slate-900 dark:text-slate-200',
                      text: '${simRebuildCount.value}',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Targeted Widget Tree
          Div(
            className:
                'lg:col-span-6 p-6 rounded-2xl bg-slate-50 '
                'dark:bg-zinc-950 border border-slate-200 '
                'dark:border-zinc-800 flex flex-col justify-between',
            children: [
              Div(
                children: [
                  Div(
                    className:
                        'flex items-center justify-between text-xs font-mono '
                        'font-bold text-slate-500 dark:text-slate-400 mb-4 pb-2 '
                        'border-b border-slate-200 dark:border-zinc-800',
                    children: [
                      Span(text: 'Flutter Widget Tree'),
                      Span(
                        className:
                            'text-emerald-600 dark:text-emerald-400 flex items-center '
                            'gap-1 text-[10px] font-bold',
                        children: [
                          hugeIcon('zap', className: 'w-3 h-3'),
                          Span(text: 'Impeller 60FPS'),
                        ],
                      ),
                    ],
                  ),
                  Div(
                    className: 'space-y-3 text-xs font-mono',
                    children: [
                      Div(
                        className:
                            'p-2.5 rounded-lg bg-white dark:bg-zinc-900 '
                            'text-slate-600 dark:text-slate-400 text-[11px] border '
                            'border-slate-200 dark:border-zinc-800',
                        text: 'Scaffold (No Rebuild)',
                      ),
                      Div(
                        className:
                            'p-2.5 rounded-lg bg-white dark:bg-zinc-900 '
                            'text-slate-600 dark:text-slate-400 text-[11px] ml-4 '
                            'border border-slate-200 dark:border-zinc-800',
                        text: 'Column (No Rebuild)',
                      ),
                      Div(
                        className:
                            'p-4 rounded-xl bg-teal-500/10 border-2 border-teal-500 '
                            'ml-8 text-teal-700 dark:text-teal-300 shadow-md '
                            'animate-pulse',
                        children: [
                          Div(
                            className: 'flex items-center justify-between font-bold',
                            children: [
                              Live(
                                () => Span(
                                  text:
                                      'Watch((context) => Text(\'Count: ${simCount.value}\'))',
                                ),
                              ),
                              Span(
                                className:
                                    'text-[10px] px-2 py-0.5 rounded bg-teal-600 text-white',
                                text: 'REBUILT',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              P(
                className: 'text-[11px] text-slate-500 dark:text-slate-400 mt-4',
                children: [
                  const Text('Only the '),
                  Code(
                    className: 'font-mono text-teal-600 dark:text-teal-400 font-bold',
                    text: 'Watch()',
                  ),
                  const Text(' widget is rebuilt when '),
                  Code(
                    className: 'font-mono text-teal-600 dark:text-teal-400 font-bold',
                    text: 'count.value',
                  ),
                  const Text(
                    ' mutates. The parent Scaffold and Column remain completely untouched.',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
