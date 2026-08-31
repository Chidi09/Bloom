import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _CommandMode {
  final String id;
  final String command;
  final String badge;
  final String description;
  final String configSnippet;
  final List<String> outputLog;
  final int trafficPct;

  const _CommandMode({
    required this.id,
    required this.command,
    required this.badge,
    required this.description,
    required this.configSnippet,
    required this.outputLog,
    required this.trafficPct,
  });
}

const _modes = <_CommandMode>[
  _CommandMode(
    id: 'patch',
    command: r'$ bloom patch --channel staging',
    badge: 'AOT_BYTECODE_PATCH',
    description:
        'Compiles Dart AOT delta bytecode and securely uploads to '
        'staging CDN nodes.',
    configSnippet: '''ota:
  app_id: "com.bloom.dashboard"
  channels:
    - staging
  rollout:
    canary_percentage: 10''',
    outputLog: [
      '[BUILD] Compiling Dart AOT byte patch for v2.4.1...',
      '[SIGN] Cryptographic RSA-2048 signature generated (SHA256: 8f9a2b)',
      '[UPLOAD] Lightweight delta patch (142.8 KB) uploaded to Staging CDN',
      '[SUCCESS] Staging channel live: v2.4.1 active across 10% canary devices',
    ],
    trafficPct: 10,
  ),
  _CommandMode(
    id: 'promote',
    command: r'$ bloom promote --from staging --to production --rollout 50',
    badge: 'CANARY_PROMOTION',
    description:
        'Promotes verified staging patch to production with '
        'controlled 50% canary traffic allocation.',
    configSnippet: '''ota:
  app_id: "com.bloom.dashboard"
  channels:
    - production
  rollout:
    canary_percentage: 50
    auto_promote: true''',
    outputLog: [
      '[PROMOTE] Promoting patch v2.4.1 to Production channel',
      '[CANARY] Scaling traffic split: 10% ➔ 50% active instances',
      '[HEALTH] Executing automated /api/health probe checks (200 OK)',
      '[SUCCESS] Production canary active: 50% traffic served by v2.4.1',
    ],
    trafficPct: 50,
  ),
  _CommandMode(
    id: 'rollback',
    command: r'$ bloom rollback --patch-v2',
    badge: 'INSTANT_ROLLBACK',
    description:
        'Instantly invalidates V2 patch pointers across Edge CDN, '
        'forcing immediate local client revert.',
    configSnippet: '''ota:
  app_id: "com.bloom.dashboard"
  channels:
    - production
  rollout:
    active_patch: "v2.4.0_fallback"''',
    outputLog: [
      '[ROLLBACK] Emergency rollback triggered for patch v2.4.1',
      '[INVALIDATE] Edge CDN cache key invalidated on 142 global nodes in 340ms',
      '[CLIENT] App instances local state restored to v2.4.0 clean build',
      '[SUCCESS] Rollback complete: 0 active errors reported',
    ],
    trafficPct: 0,
  ),
];

BloomNode otaReleasePlayground() {
  final activeModeId = signal('patch');

  return Div(
    className:
        'p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl '
        'mx-auto space-y-8 text-left',
    children: [
      // Header & Mode Switcher
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
                  hugeIcon('server', className: 'w-5 h-5 text-blue-500'),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text: 'Declarative Release Management Sandbox',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Select a deployment mode to inspect bloom.yaml configs '
                    'and CLI outputs.',
              ),
            ],
          ),
          Div(
            className: 'flex items-center gap-2',
            children: [
              for (final m in _modes)
                Live(() {
                  final isActive = activeModeId.value == m.id;
                  return Button(
                    attrs: {'type': 'button'},
                    onClick: (_) => activeModeId.value = m.id,
                    className:
                        'px-3.5 py-2 rounded-xl text-xs font-mono font-bold '
                        'transition-all border cursor-pointer ${isActive ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md scale-105' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'}',
                    text: m.id.toUpperCase(),
                  );
                }),
            ],
          ),
        ],
      ),

      // Traffic Rollout Visualizer Bar
      Live(() {
        final active = _modes.firstWhere(
          (m) => m.id == activeModeId.value,
          orElse: () => _modes.first,
        );

        return Div(
          className:
              'p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
              'border-slate-200 dark:border-zinc-800 space-y-3 font-mono text-xs',
          children: [
            Div(
              className:
                  'flex items-center justify-between text-slate-600 '
                  'dark:text-slate-400 font-bold',
              children: [
                Span(text: 'Canary Traffic Allocation: ${active.trafficPct}%'),
                Span(
                  className: 'text-purple-600 dark:text-purple-400',
                  text: active.badge,
                ),
              ],
            ),
            Div(
              className:
                  'w-full h-3 bg-slate-200 dark:bg-zinc-800 rounded-full '
                  'overflow-hidden shadow-inner',
              children: [
                Div(
                  className:
                      'h-full bg-gradient-to-r from-blue-500 via-purple-500 '
                      'to-pink-500 rounded-full transition-all duration-500',
                  style: 'width: ${active.trafficPct}%;',
                ),
              ],
            ),
          ],
        );
      }),

      // Grid: Config vs Terminal Output
      Live(() {
        final active = _modes.firstWhere(
          (m) => m.id == activeModeId.value,
          orElse: () => _modes.first,
        );

        return Div(
          className:
              'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch '
              'font-mono text-xs',
          children: [
            // Left: bloom.yaml snippet
            Div(
              className: 'lg:col-span-6 space-y-3',
              children: [
                Div(
                  className: 'text-slate-500 dark:text-slate-400 font-bold',
                  text: '📄 bloom.yaml (Release Config)',
                ),
                Div(
                  className:
                      'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                      'border border-slate-800 dark:border-zinc-800 shadow-xl',
                  children: [
                    Pre(
                      className:
                          'p-4 sm:p-5 leading-relaxed overflow-x-auto '
                          'text-purple-300',
                      children: [Code(text: active.configSnippet)],
                    ),
                  ],
                ),
              ],
            ),

            // Right: CLI Terminal Output
            Div(
              className: 'lg:col-span-6 space-y-3',
              children: [
                Div(
                  className:
                      'flex items-center justify-between text-slate-500 '
                      'dark:text-slate-400 font-bold',
                  children: [
                    Span(text: '💻 Terminal Execution Log'),
                    Span(
                      className: 'text-emerald-500 font-bold',
                      text: active.command,
                    ),
                  ],
                ),
                Div(
                  className:
                      'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                      'border border-slate-800 dark:border-zinc-800 shadow-xl p-4 '
                      'sm:p-5 space-y-2',
                  children: [
                    for (final line in active.outputLog)
                      Div(
                        className:
                            'text-[11px] ${line.contains('[SUCCESS]')
                                ? 'text-emerald-400 font-bold'
                                : line.contains('[ROLLBACK]')
                                ? 'text-rose-400 font-bold'
                                : 'text-slate-300'}',
                        text: line,
                      ),
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
