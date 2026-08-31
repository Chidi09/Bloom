import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final signalDemoCount = signal(42);
final queryDemoState = signal('SUCCESS');
final genDemoCount = signal(14);

BloomNode featureGridShowcase() {
  final features = const [
    (
      'routing',
      'folder-tree',
      'File-System Routing',
      'Next.js-style directory routing over go_router with typed params, layout groups, and route guards.',
      'ARCHITECTURE',
      '#8B5CF6',
    ),
    (
      'signals',
      'zap',
      'Signals Reactive State',
      'Fine-grained reactivity with zero setState. Rebuilds only the exact widgets reading a signal at 60fps.',
      'STATE_ENGINE',
      '#20C9B0',
    ),
    (
      'query',
      'database',
      'Bloom Query',
      'Declarative server-state caching, background refetching, and pagination with optimistic mutations.',
      'SERVER_STATE',
      '#FF884D',
    ),
    (
      'ota',
      'rocket',
      'Shorebird OTA Updates',
      'Code-signed over-the-air byte patches with canary rollouts, instant rollback, and zero App Store delays.',
      'CLOUD_DEPLOY',
      '#3B82F6',
    ),
    (
      'studio',
      'layers',
      'Bloom UI Studio',
      'shadcn-style composable primitives with live design-token controls for Flutter Mobile & Web.',
      'UI_SYSTEM',
      '#FF4B8B',
    ),
    (
      'codegen',
      'code',
      'Deterministic Code Gen',
      'CLI generators scaffold routes, controllers, and models deterministically on file save in sub-50ms.',
      'CLI_AST',
      '#10B981',
    ),
  ];

  return Div(
    className:
        'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 '
        'max-w-6xl mx-auto',
    children: [
      for (final (id, icon, title, desc, badge, _) in features)
        Div(
          className:
              'group relative p-7 rounded-3xl bg-white dark:bg-black '
              'backdrop-blur border border-slate-200 '
              'dark:border-zinc-800 hover:border-slate-300 '
              'dark:hover:border-zinc-700 hover:shadow-xl '
              'transition-all duration-300 flex flex-col '
              'justify-between',
          children: [
            Div(
              children: [
                // Header Icon & Badge
                Div(
                  className: 'flex items-center justify-between mb-5',
                  children: [
                    Div(
                      className:
                          'w-10 h-10 rounded-xl bg-slate-100 dark:bg-zinc-900 flex '
                          'items-center justify-center text-slate-800 '
                          'dark:text-white',
                      children: [hugeIcon(icon, className: 'w-5 h-5')],
                    ),
                    Span(
                      className:
                          'text-[10px] font-mono font-bold px-2.5 py-1 rounded-full '
                          'bg-slate-100 dark:bg-zinc-900 text-slate-500 '
                          'dark:text-slate-400 border border-slate-200 '
                          'dark:border-zinc-800',
                      text: badge,
                    ),
                  ],
                ),
                H3(
                  className:
                      'text-xl font-bold text-slate-900 dark:text-white mb-2',
                  text: title,
                ),
                P(
                  className:
                      'text-xs text-slate-600 dark:text-slate-400 '
                      'leading-relaxed mb-6 font-normal',
                  text: desc,
                ),
              ],
            ),

            // Mini Reactive Sandbox Widget for each feature
            if (id == 'signals')
              Div(
                className:
                    'p-3 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                    'border-slate-200 dark:border-zinc-800 flex items-center '
                    'justify-between text-xs font-mono',
                children: [
                  Live(
                    () => Span(
                      className: 'text-teal-500 font-bold',
                      text: 'count = ${signalDemoCount.value}',
                    ),
                  ),
                  Button(
                    onClick: (_) => signalDemoCount.value++,
                    className:
                        'px-2.5 py-1 rounded-lg bg-teal-600 hover:bg-teal-500 '
                        'text-white font-bold text-[11px] transition-colors',
                    text: 'count.value++',
                  ),
                ],
              )
            else if (id == 'query')
              Div(
                className:
                    'p-3 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                    'border-slate-200 dark:border-zinc-800 flex items-center '
                    'justify-between text-xs font-mono',
                children: [
                  Live(
                    () => Span(
                      className: queryDemoState.value == 'FETCHING'
                          ? 'text-amber-400 font-bold'
                          : 'text-emerald-400 font-bold',
                      text: queryDemoState.value == 'FETCHING'
                          ? 'FETCHING...'
                          : 'CACHE: 200 OK',
                    ),
                  ),
                  Button(
                    onClick: (_) {
                      queryDemoState.value = 'FETCHING';
                      Future.delayed(const Duration(milliseconds: 600), () {
                        queryDemoState.value = 'SUCCESS';
                      });
                    },
                    className:
                        'px-2.5 py-1 rounded-lg bg-orange-600 hover:bg-orange-500 '
                        'text-white font-bold text-[11px] transition-colors',
                    text: 'refetch()',
                  ),
                ],
              )
            else if (id == 'codegen')
              Div(
                className:
                    'p-3 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                    'border-slate-200 dark:border-zinc-800 flex items-center '
                    'justify-between text-xs font-mono',
                children: [
                  Live(
                    () => Span(
                      className: 'text-emerald-400 font-bold',
                      text: '${genDemoCount.value} routes compiled',
                    ),
                  ),
                  Button(
                    onClick: (_) => genDemoCount.value++,
                    className:
                        'px-2.5 py-1 rounded-lg bg-emerald-600 '
                        'hover:bg-emerald-500 text-white font-bold text-[11px] '
                        'transition-colors',
                    text: '+ add route',
                  ),
                ],
              )
            else
              Div(
                className:
                    'p-3 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                    'border-slate-200 dark:border-zinc-800 flex items-center '
                    'justify-between text-[11px] font-mono text-slate-500',
                children: [
                  Span(text: 'Architecture Pillar'),
                  Span(className: 'text-purple-400 font-bold', text: 'Active'),
                ],
              ),
          ],
        ),
    ],
  );
}
