import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final bootRunning = signal(false);
final bootStep = signal(0);

BloomNode bootDIVisualizer() {
  final steps = const [
    (
      1,
      '1. Load bloom.yaml',
      'Parsing environment vars, channels & logging levels',
      '4ms',
      '[BOOT] Environment initialized: production (bloom.yaml)',
    ),
    (
      2,
      '2. Register DI Singletons',
      'Injecting AuthService, ApiClient & StorageService',
      '12ms',
      '[DI] Containers registered: AuthService, ApiClient, StorageService',
    ),
    (
      3,
      '3. Attach Signals Router',
      'Compiling AST route table and state dependencies',
      '8ms',
      '[ROUTER] 14 typed routes compiled over go_router',
    ),
    (
      4,
      '4. Execute runApp(MyApp())',
      'Mounting Flutter root widget with Impeller 60fps',
      '16ms',
      '[RUN_APP] Flutter Engine running cleanly on metal graphics thread',
    ),
  ];

  void runBoot() {
    bootRunning.value = true;
    bootStep.value = 1;

    Future.delayed(const Duration(milliseconds: 600), () {
      bootStep.value = 2;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      bootStep.value = 3;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      bootStep.value = 4;
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      bootStep.value = 5;
      bootRunning.value = false;
    });
  }

  return Div(
    className:
        'p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black '
        'backdrop-blur border border-slate-200 '
        'dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto '
        'space-y-8 text-left',
    children: [
      // Header & Interactive Control
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
                    'cpu',
                    className: 'w-5 h-5 text-purple-600 dark:text-purple-400',
                  ),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Interactive Boot & DI Execution Pipeline',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                children: [
                  const Text(
                    'Click run to simulate Bloom’s sub-40ms boot sequence before Flutter mounts ',
                  ),
                  Code(
                    className:
                        'font-mono text-purple-600 dark:text-purple-400 font-bold',
                    text: 'runApp()',
                  ),
                  const Text('.'),
                ],
              ),
            ],
          ),
          Live(() {
            final isRunning = bootRunning.value;
            return Button(
              attrs: {
                'type': 'button',
                if (isRunning) 'disabled': 'disabled',
              },
              onClick: (_) => runBoot(),
              className:
                  'inline-flex items-center gap-2 px-5 py-2.5 rounded-xl '
                  'bg-slate-900 dark:bg-white text-white '
                  'dark:text-slate-950 font-black text-xs shadow-lg '
                  'hover:bg-slate-800 dark:hover:bg-slate-200 '
                  'transition-all active:scale-95 disabled:opacity-50 '
                  'cursor-pointer',
              children: [
                hugeIcon(
                  'play',
                  className: 'w-3.5 h-3.5 ${isRunning ? 'animate-spin' : ''}',
                ),
                Span(
                  text: isRunning ? 'Executing Boot...' : 'Run Boot Sequence',
                ),
              ],
            );
          }),
        ],
      ),

      // Grid: 4 Boot Sequence Nodes
      Div(
        className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4',
        children: [
          for (final (num, label, action, dur, _) in steps)
            Live(() {
              final step = bootStep.value;
              final isDone = step == 0 || step > num;
              final isCurrent = step == num;

              final String cardClass;
              if (isCurrent) {
                cardClass =
                    'bg-slate-900 text-white dark:bg-zinc-900 '
                    'dark:border-white shadow-xl scale-105';
              } else if (isDone) {
                cardClass =
                    'bg-slate-50 dark:bg-zinc-950 border-slate-200 '
                    'dark:border-zinc-800 text-slate-900 dark:text-white';
              } else {
                cardClass =
                    'bg-slate-50/60 dark:bg-zinc-950/60 border-slate-200 '
                    'dark:border-zinc-900 opacity-60 text-slate-500';
              }

              return Div(
                className:
                    'p-5 rounded-2xl border transition-all duration-300 $cardClass',
                children: [
                  Div(
                    className: 'flex items-center justify-between mb-3',
                    children: [
                      Span(
                        className:
                            'text-[10px] font-mono font-bold text-slate-500 '
                            'dark:text-slate-400',
                        text: dur,
                      ),
                      if (isDone)
                        hugeIcon(
                          'check-circle',
                          className:
                              'w-4 h-4 text-emerald-600 dark:text-emerald-400',
                        )
                      else if (isCurrent)
                        hugeIcon(
                          'refresh',
                          className:
                              'w-4 h-4 text-amber-500 dark:text-amber-400 '
                              'animate-spin',
                        )
                      else
                        Div(
                          className:
                              'w-2.5 h-2.5 rounded-full bg-slate-300 '
                              'dark:bg-zinc-800',
                        ),
                    ],
                  ),
                  Div(
                    className:
                        'text-xs font-bold text-slate-900 dark:text-white mb-1',
                    text: label,
                  ),
                  Div(
                    className:
                        'text-[11px] text-slate-600 dark:text-slate-400 '
                        'leading-snug',
                    text: action,
                  ),
                ],
              );
            }),
        ],
      ),

      // Terminal Log Console Output
      Live(() {
        final step = bootStep.value;
        final visible = step == 0
            ? steps.length
            : (step < steps.length ? step : steps.length);
        return Div(
          className:
              'p-5 rounded-2xl bg-slate-950 dark:bg-black border border-slate-800 '
              'dark:border-zinc-800 font-mono text-xs space-y-2 text-white '
              'shadow-xl',
          children: [
            Div(
              className:
                  'flex items-center justify-between text-[11px] text-slate-400 '
                  'pb-2 border-b border-slate-800 dark:border-zinc-800',
              children: [
                Span(text: 'Execution Log Console'),
                Span(
                  className: 'text-emerald-400 font-bold',
                  text: 'TOTAL: 40ms',
                ),
              ],
            ),
            Div(
              className: 'space-y-1.5 pt-1 text-slate-300',
              children: [
                for (final (_, _, _, _, log) in steps.take(visible))
                  Div(
                    className: 'flex items-center gap-2 text-[11px]',
                    children: [
                      Span(
                        className: 'text-emerald-400 font-bold',
                        text: '✔',
                      ),
                      Span(text: log),
                    ],
                  ),
              ],
            ),
          ],
        );
      }),
    ],
  );
}
