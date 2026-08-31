import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final queryStatus = signal('FRESH');
final queryItems = signal<List<String>>([
  'User Profile #42',
  'User Preferences',
  'Security Tokens',
]);
final queryLog = signal('Query initialized with 5m staleTime');

BloomNode bloomQueryPlayground() {

  return Div(
    className:
        'p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
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
                  hugeIcon('zap', className: 'w-5 h-5 text-amber-500'),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Interactive Bloom Query & Cache Sandbox',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Test automatic background refetching, focus revalidation, '
                    'and optimistic mutations.',
              ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              Live(() {
                final isFetching = queryStatus.value == 'FETCHING';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) {
                    queryStatus.value = 'FETCHING';
                    queryLog.value = '[REFETCH] Revalidating in background...';
                    Future.delayed(const Duration(milliseconds: 700), () {
                      queryStatus.value = 'FRESH';
                      queryLog.value = '[SUCCESS] Cache updated in background';
                    });
                  },
                  className:
                      'px-4 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white '
                      'dark:text-slate-950 font-black text-xs shadow-md '
                      'hover:bg-slate-800 dark:hover:bg-slate-200 transition-all '
                      'active:scale-95 cursor-pointer ${isFetching ? 'opacity-50 pointer-events-none' : ''}',
                  text: 'Trigger Refetch',
                );
              }),
              Button(
                attrs: {'type': 'button'},
                onClick: (_) {
                  queryStatus.value = 'OPTIMISTIC_MUTATION';
                  queryItems.value = [
                    ...queryItems.value,
                    'Optimistic Entry #${queryItems.value.length + 1}',
                  ];
                  queryLog.value =
                      '[MUTATION] Added optimistically before server ACK';

                  Future.delayed(const Duration(milliseconds: 900), () {
                    queryStatus.value = 'FRESH';
                    queryLog.value = '[SERVER_ACK] Server validated mutation';
                  });
                },
                className:
                    'px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-zinc-900 '
                    'border border-slate-200 dark:border-zinc-800 text-slate-900 '
                    'dark:text-white font-bold text-xs hover:bg-slate-200 '
                    'dark:hover:bg-zinc-800 transition-all active:scale-95 '
                    'cursor-pointer',
                text: '+ Optimistic Item',
              ),
            ],
          ),
        ],
      ),

      // Main Sandbox Grid
      Div(
        className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch',
        children: [
          // Left: Query Cache Node State
          Div(
            className:
                'lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                'border border-slate-200 dark:border-zinc-800 font-mono '
                'text-xs space-y-4',
            children: [
              Div(
                className:
                    'flex items-center justify-between text-[11px] '
                    'text-slate-500 dark:text-slate-400 pb-2 border-b '
                    'border-slate-200 dark:border-zinc-800',
                children: [
                  Span(text: "Query Cache Key: ['user', 42]"),
                  Live(() {
                    final status = queryStatus.value;
                    final isFetching = status == 'FETCHING';
                    return Span(
                      className:
                          'font-bold ${isFetching ? 'text-amber-500 animate-pulse' : 'text-emerald-600 dark:text-emerald-400'}',
                      text: 'STATUS: $status',
                    );
                  }),
                ],
              ),
              Live(() {
                return Div(
                  className: 'space-y-2',
                  children: [
                    for (final item in queryItems.value)
                      Div(
                        className:
                            'p-3 rounded-xl bg-white dark:bg-zinc-900 border '
                            'border-slate-200 dark:border-zinc-800 flex '
                            'items-center justify-between',
                        children: [
                          Span(
                            className: 'text-slate-700 dark:text-slate-300',
                            text: item,
                          ),
                          Span(
                            className: 'text-[10px] font-mono text-slate-400',
                            text: 'Cached',
                          ),
                        ],
                      ),
                  ],
                );
              }),
              Div(
                className:
                    'text-[11px] text-slate-500 pt-2 border-t '
                    'border-slate-200 dark:border-zinc-800',
                text: 'staleTime: 5m  ·  gcTime: 24h  ·  retry: 3',
              ),
            ],
          ),

          // Right: Real-time Event Logger
          Div(
            className:
                'lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                'border border-slate-200 dark:border-zinc-800 flex flex-col '
                'justify-between font-mono text-xs',
            children: [
              Div(
                children: [
                  Div(
                    className:
                        'flex items-center justify-between text-[11px] '
                        'text-slate-500 dark:text-slate-400 pb-2 border-b '
                        'border-slate-200 dark:border-zinc-800 mb-3',
                    children: [
                      Span(text: 'Cache Lifecycle Event'),
                      Span(
                        className:
                            'text-emerald-600 dark:text-emerald-400 font-bold',
                        text: 'MEMORY_ACTIVE',
                      ),
                    ],
                  ),
                  Live(() {
                    return Div(
                      className:
                          'p-3.5 rounded-xl bg-white dark:bg-zinc-900 border '
                          'border-slate-200 dark:border-zinc-800 text-slate-700 '
                          'dark:text-slate-200 leading-relaxed',
                      text: queryLog.value,
                    );
                  }),
                ],
              ),
              Div(
                className:
                    'mt-4 p-3 rounded-xl bg-amber-500/10 border '
                    'border-amber-500/20 text-amber-700 dark:text-amber-400 '
                    'text-[11px]',
                children: [
                  const Text(
                    '⚡️ Mutations render on device immediately, auto-reverting '
                    'if the remote API network call rejects.',
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
