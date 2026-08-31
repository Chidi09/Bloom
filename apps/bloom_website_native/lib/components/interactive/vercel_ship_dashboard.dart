import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _Deployment {
  final String id;
  final String commit;
  final String message;
  final String author;
  final String branch;
  final String status;
  final String time;
  final String size;
  final String duration;

  const _Deployment({
    required this.id,
    required this.commit,
    required this.message,
    required this.author,
    required this.branch,
    required this.status,
    required this.time,
    required this.size,
    required this.duration,
  });

  _Deployment copyWith({String? status}) {
    return _Deployment(
      id: id,
      commit: commit,
      message: message,
      author: author,
      branch: branch,
      status: status ?? this.status,
      time: time,
      size: size,
      duration: duration,
    );
  }
}

final _initialDeployments = <_Deployment>[
  const _Deployment(
    id: 'dpl_89f2a01',
    commit: '04a2f8c',
    message: 'feat(signals): hot reload state preservation in dev client',
    author: 'chidi09',
    branch: 'main',
    status: 'ready',
    time: '2 mins ago',
    size: '142.8 KB',
    duration: '1.2s',
  ),
  const _Deployment(
    id: 'dpl_74e1c99',
    commit: '991a34b',
    message: 'fix(ota): RSA-2048 cryptographic signature validation',
    author: 'chidi09',
    branch: 'staging',
    status: 'ready',
    time: '14 mins ago',
    size: '138.4 KB',
    duration: '1.4s',
  ),
  const _Deployment(
    id: 'dpl_61b8f02',
    commit: '18f77a2',
    message: 'perf(engine): flutter 3.29 Skia/Impeller shader warmup',
    author: 'bloom-bot',
    branch: 'canary',
    status: 'ready',
    time: '1 hour ago',
    size: '156.1 KB',
    duration: '1.8s',
  ),
];

BloomNode vercelShipDashboard() {
  final activeTab = signal('deployments');
  final rollout = signal(100);
  final deployments = signal<List<_Deployment>>(_initialDeployments);
  final isDeploying = signal(false);
  final logs = signal<List<String>>([
    '[01:54:10] INFO: Listening on Edge CDN cluster (142 nodes worldwide)',
    '[01:54:12] SUCCESS: RSA-2048 public key verification passed',
    '[01:54:15] BROADCAST: OTA bundle dpl_89f2a01 active across 400,000 devices',
  ]);

  void triggerNewDeployment() {
    isDeploying.value = true;
    final now = DateTime.now().toIso8601String().substring(11, 19);
    final newId =
        'dpl_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final newCommit = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .substring(0, 7);

    logs.value = [
      '[$now] TRIGGER: \$ bloom ship --prod --channel=production',
      '[$now] COMPILING: AOT Dart bytecode patch...',
      ...logs.value,
    ];

    Timer(const Duration(milliseconds: 1800), () {
      final doneTime = DateTime.now().toIso8601String().substring(11, 19);
      logs.value = [
        '[$doneTime] SIGNING: Cryptographic RSA-2048 signature generated',
        '[$doneTime] BROADCAST: Pushed to 142 Edge CDN nodes in 1.1s',
        ...logs.value,
      ];

      final newDpl = _Deployment(
        id: newId,
        commit: newCommit,
        message: 'chore(release): automated canary OTA patch deployment',
        author: 'you (CLI)',
        branch: 'main',
        status: 'ready',
        time: 'Just now',
        size: '141.2 KB',
        duration: '1.1s',
      );

      deployments.value = [newDpl, ...deployments.value];
      isDeploying.value = false;
    });
  }

  void rollbackDeployment(String id) {
    deployments.value = deployments.value
        .map((d) => d.id == id ? d.copyWith(status: 'rolled_back') : d)
        .toList();

    final now = DateTime.now().toIso8601String().substring(11, 19);
    logs.value = [
      '[$now] WARN: Rollback triggered for deployment $id',
      '[$now] SUCCESS: Reverted active patch pointers to previous stable bundle',
      ...logs.value,
    ];
  }

  return Div(
    className:
        'w-full max-w-5xl mx-auto rounded-3xl bg-white dark:bg-black '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl '
        'overflow-hidden font-sans text-slate-800 dark:text-slate-200 text-left',
    children: [
      // Top Header Bar
      Div(
        className:
            'px-6 py-4 bg-slate-50 dark:bg-zinc-950/90 border-b '
            'border-slate-200 dark:border-zinc-800 flex flex-wrap '
            'items-center justify-between gap-4 backdrop-blur-xl',
        children: [
          Div(
            className: 'flex items-center gap-3',
            children: [
              Div(
                className:
                    'w-8 h-8 rounded-xl bg-white dark:bg-zinc-900 border '
                    'border-slate-200 dark:border-zinc-700 flex items-center '
                    'justify-center shadow-sm',
                children: [
                  hugeIcon('server', className: 'w-4 h-4 text-blue-500'),
                ],
              ),
              Div(
                children: [
                  Div(
                    className: 'flex items-center gap-2',
                    children: [
                      Span(
                        className:
                            'font-mono font-black text-sm text-slate-900 '
                            'dark:text-white tracking-tight',
                        text: 'bloom-cloud-ota',
                      ),
                      Span(
                        className:
                            'px-2.5 py-0.5 rounded-full bg-emerald-500/15 border '
                            'border-emerald-500/30 text-[10px] font-mono font-bold '
                            'text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5',
                        children: [
                          Span(
                            className:
                                'w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse',
                          ),
                          const Text('ACTIVE'),
                        ],
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'text-[11px] text-slate-500 dark:text-slate-400 font-mono '
                        'mt-0.5',
                    text:
                        '142 Edge CDN Nodes · RSA-2048 Signed · Shorebird Powered',
                  ),
                ],
              ),
            ],
          ),
          Live(() {
            final deploying = isDeploying.value;
            return Button(
              attrs: {'type': 'button'},
              onClick: (_) => triggerNewDeployment(),
              className:
                  'px-4 py-2 rounded-xl bg-slate-900 dark:bg-white '
                  'hover:bg-slate-800 dark:hover:bg-slate-200 text-white '
                  'dark:text-slate-950 font-mono text-xs font-black flex '
                  'items-center gap-2 transition active:scale-95 shadow-md cursor-pointer ${deploying ? 'opacity-50 pointer-events-none' : ''}',
              children: [
                hugeIcon(
                  deploying ? 'refresh' : 'sparkles',
                  className: 'w-3.5 h-3.5',
                ),
                Text(deploying ? 'Packaging Patch...' : 'Ship New Patch'),
              ],
            );
          }),
        ],
      ),

      // Top Telemetry Stats Strip
      Div(
        className:
            'grid grid-cols-2 sm:grid-cols-4 border-b border-slate-200 '
            'dark:border-zinc-800 bg-slate-50/50 dark:bg-zinc-950/60 divide-x '
            'divide-slate-200 dark:divide-zinc-800/80 font-mono text-xs',
        children: [
          Div(
            className: 'p-3.5 px-6',
            children: [
              Span(
                className:
                    'text-[10px] text-slate-500 dark:text-slate-400 uppercase '
                    'block font-bold',
                text: 'Active Patch',
              ),
              Span(
                className: 'text-slate-900 dark:text-white font-bold text-xs',
                text: 'v2.5.1-production',
              ),
            ],
          ),
          Div(
            className: 'p-3.5 px-6',
            children: [
              Span(
                className:
                    'text-[10px] text-slate-500 dark:text-slate-400 uppercase '
                    'block font-bold',
                text: 'Edge Latency',
              ),
              Span(
                className:
                    'text-emerald-600 dark:text-emerald-400 font-bold text-xs',
                text: '1.1s (142 Nodes)',
              ),
            ],
          ),
          Div(
            className: 'p-3.5 px-6',
            children: [
              Span(
                className:
                    'text-[10px] text-slate-500 dark:text-slate-400 uppercase '
                    'block font-bold',
                text: 'Devices Reached',
              ),
              Span(
                className: 'text-blue-600 dark:text-blue-400 font-bold text-xs',
                text: '400,000 Active',
              ),
            ],
          ),
          Div(
            className: 'p-3.5 px-6',
            children: [
              Span(
                className:
                    'text-[10px] text-slate-500 dark:text-slate-400 uppercase '
                    'block font-bold',
                text: 'Canary Rollout',
              ),
              Live(() {
                return Span(
                  className:
                      'text-purple-600 dark:text-purple-400 font-bold text-xs',
                  text: '${rollout.value}% Global',
                );
              }),
            ],
          ),
        ],
      ),

      // Navigation Tabs Bar
      Div(
        className:
            'px-6 border-b border-slate-200 dark:border-zinc-800 bg-slate-50/30 '
            'dark:bg-zinc-950/40 flex items-center justify-between overflow-x-auto',
        children: [
          Div(
            className: 'flex items-center gap-6',
            children: [
              Live(() {
                final isDeployments = activeTab.value == 'deployments';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) => activeTab.value = 'deployments',
                  className:
                      'py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 cursor-pointer ${isDeployments ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}',
                  children: [
                    hugeIcon('code', className: 'w-3.5 h-3.5 text-blue-500'),
                    Text('Deployments (${deployments.value.length})'),
                  ],
                );
              }),
              Live(() {
                final isPipeline = activeTab.value == 'pipeline';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) => activeTab.value = 'pipeline',
                  className:
                      'py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 cursor-pointer ${isPipeline ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}',
                  children: [
                    hugeIcon('zap', className: 'w-3.5 h-3.5 text-purple-500'),
                    const Text('Rollout & Channels'),
                  ],
                );
              }),
              Live(() {
                final isWebhooks = activeTab.value == 'webhooks';
                return Button(
                  attrs: {'type': 'button'},
                  onClick: (_) => activeTab.value = 'webhooks',
                  className:
                      'py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 cursor-pointer ${isWebhooks ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'}',
                  children: [
                    hugeIcon('server', className: 'w-3.5 h-3.5 text-teal-500'),
                    const Text('Edge Event Stream'),
                  ],
                );
              }),
            ],
          ),
          Div(
            className:
                'hidden sm:flex items-center gap-2 text-[11px] font-mono '
                'text-slate-500 dark:text-slate-400',
            children: [
              Span(text: 'Target Branch:'),
              Span(
                className:
                    'px-2 py-0.5 rounded bg-slate-100 dark:bg-zinc-900 '
                    'text-slate-900 dark:text-white font-bold border '
                    'border-slate-200 dark:border-zinc-800',
                text: 'main',
              ),
            ],
          ),
        ],
      ),

      // Main Body Views
      Div(
        className: 'p-6 space-y-6',
        children: [
          Live(() {
            final tab = activeTab.value;

            if (tab == 'deployments') {
              return Div(
                className: 'space-y-4',
                children: [
                  Div(
                    className:
                        'text-xs font-mono text-slate-500 dark:text-slate-400 '
                        'uppercase tracking-wider mb-2 flex items-center justify-between',
                    children: [
                      Span(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: 'Production & Staging Build Log',
                      ),
                      Span(text: 'Sorted by Recency'),
                    ],
                  ),
                  Div(
                    className: 'space-y-3',
                    children: [
                      for (final dpl in deployments.value)
                        Div(
                          className:
                              'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 '
                              'hover:bg-slate-100 dark:hover:bg-zinc-900 border '
                              'border-slate-200 dark:border-zinc-800 transition-all '
                              'flex flex-col sm:flex-row sm:items-center '
                              'justify-between gap-4 group shadow-sm',
                          children: [
                            Div(
                              className: 'flex items-start gap-3.5',
                              children: [
                                Div(
                                  className: 'mt-1',
                                  children: [
                                    if (dpl.status == 'ready')
                                      Div(
                                        className:
                                            'w-6 h-6 rounded-full bg-emerald-500/10 '
                                            'border border-emerald-500/30 flex '
                                            'items-center justify-center',
                                        children: [
                                          hugeIcon(
                                            'check-circle',
                                            className:
                                                'w-3.5 h-3.5 text-emerald-500',
                                          ),
                                        ],
                                      )
                                    else
                                      Div(
                                        className:
                                            'w-6 h-6 rounded-full bg-rose-500/10 '
                                            'border border-rose-500/30 flex '
                                            'items-center justify-center',
                                        children: [
                                          hugeIcon(
                                            'refresh',
                                            className:
                                                'w-3.5 h-3.5 text-rose-500',
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                Div(
                                  children: [
                                    Div(
                                      className:
                                          'flex items-center gap-2 font-mono text-xs',
                                      children: [
                                        Span(
                                          className:
                                              'font-bold text-slate-900 '
                                              'dark:text-white group-hover:text-purple-600 '
                                              'dark:group-hover:text-purple-300 transition-colors',
                                          text: dpl.message,
                                        ),
                                        Span(
                                          className:
                                              'px-2 py-0.5 rounded bg-slate-200 '
                                              'dark:bg-zinc-900 text-[10px] '
                                              'text-purple-700 dark:text-purple-400 '
                                              'font-bold border border-slate-300 '
                                              'dark:border-zinc-800',
                                          text: dpl.commit,
                                        ),
                                      ],
                                    ),
                                    Div(
                                      className:
                                          'flex flex-wrap items-center gap-3 '
                                          'text-[11px] font-mono text-slate-500 '
                                          'dark:text-slate-400 mt-1.5',
                                      children: [
                                        Span(
                                          className:
                                              'text-slate-900 dark:text-white font-bold',
                                          text: dpl.author,
                                        ),
                                        Span(text: '•'),
                                        Span(
                                          className:
                                              'text-purple-600 dark:text-purple-400',
                                          text: dpl.branch,
                                        ),
                                        Span(text: '•'),
                                        Span(text: dpl.size),
                                        Span(text: '•'),
                                        Span(text: dpl.time),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Div(
                              className:
                                  'flex items-center gap-3 self-end sm:self-center',
                              children: [
                                Span(
                                  className:
                                      'text-xs font-mono text-slate-700 '
                                      'dark:text-slate-200 font-bold bg-white '
                                      'dark:bg-zinc-900 px-3 py-1 rounded-xl border '
                                      'border-slate-200 dark:border-zinc-800 shadow-sm',
                                  text: dpl.duration,
                                ),
                                if (dpl.status == 'ready')
                                  Button(
                                    attrs: {'type': 'button'},
                                    onClick: (_) => rollbackDeployment(dpl.id),
                                    className:
                                        'px-3 py-1 rounded-xl bg-rose-500/10 '
                                        'hover:bg-rose-500/20 text-rose-600 '
                                        'dark:text-rose-400 text-xs font-mono '
                                        'font-bold border border-rose-500/30 '
                                        'transition flex items-center gap-1.5 '
                                        'cursor-pointer',
                                    children: [
                                      hugeIcon(
                                        'refresh',
                                        className: 'w-3 h-3 text-rose-500',
                                      ),
                                      const Text('Rollback'),
                                    ],
                                  )
                                else
                                  Span(
                                    className:
                                        'px-2.5 py-1 rounded-xl bg-rose-500/10 '
                                        'text-rose-600 dark:text-rose-400 '
                                        'text-[10px] font-mono font-bold border '
                                        'border-rose-500/20',
                                    text: 'ROLLED_BACK',
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

            if (tab == 'pipeline') {
              return Div(
                className: 'space-y-6',
                children: [
                  Div(
                    className:
                        'p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                        'border-slate-200 dark:border-zinc-800 space-y-4',
                    children: [
                      Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Div(
                            children: [
                              H4(
                                className:
                                    'font-mono font-bold text-sm text-slate-900 '
                                    'dark:text-white',
                                text: 'Gradual Canary Traffic Split',
                              ),
                              P(
                                className:
                                    'text-xs text-slate-500 dark:text-slate-400 mt-0.5',
                                text:
                                    'Control percentage of active mobile devices '
                                    'receiving patch updates.',
                              ),
                            ],
                          ),
                          Div(
                            className:
                                'text-xl font-mono font-black text-slate-900 '
                                'dark:text-white bg-white dark:bg-zinc-900 px-4 '
                                'py-1.5 rounded-xl border border-slate-200 '
                                'dark:border-zinc-800 shadow-sm',
                            text: '${rollout.value}%',
                          ),
                        ],
                      ),
                      Input(
                        attrs: {
                          'type': 'range',
                          'min': '0',
                          'max': '100',
                          'step': '10',
                          'value': '${rollout.value}',
                        },
                        onInput: (e) {
                          final val = e.value;
                          if (val != null) {
                            rollout.value = int.tryParse(val) ?? 100;
                          }
                        },
                        className:
                            'w-full h-2 bg-slate-200 dark:bg-zinc-900 rounded-lg '
                            'appearance-none cursor-pointer accent-purple-600',
                      ),
                      Div(
                        className:
                            'flex items-center justify-between text-[11px] font-mono '
                            'text-slate-500 dark:text-slate-400',
                        children: [
                          Span(text: '0% (Internal Staging)'),
                          Span(text: '50% (Canary Batch)'),
                          Span(text: '100% (Full Production)'),
                        ],
                      ),
                    ],
                  ),
                  Div(
                    className: 'grid grid-cols-1 sm:grid-cols-2 gap-4',
                    children: [
                      Div(
                        className:
                            'p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                            'border-slate-200 dark:border-zinc-800 space-y-2',
                        children: [
                          Div(
                            className: 'flex items-center justify-between',
                            children: [
                              Span(
                                className:
                                    'text-xs font-mono font-bold text-slate-900 '
                                    'dark:text-white',
                                text: 'RSA-2048 Hardware Keys',
                              ),
                              hugeIcon(
                                'sparkles',
                                className:
                                    'w-4 h-4 text-purple-600 dark:text-purple-400',
                              ),
                            ],
                          ),
                          P(
                            className:
                                'text-xs text-slate-500 dark:text-slate-400 '
                                'leading-relaxed',
                            text:
                                'Cryptographic hardware signing key verified '
                                'against local device trust store.',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                            'border-slate-200 dark:border-zinc-800 space-y-2',
                        children: [
                          Div(
                            className: 'flex items-center justify-between',
                            children: [
                              Span(
                                className:
                                    'text-xs font-mono font-bold text-slate-900 '
                                    'dark:text-white',
                                text: 'Edge CDN Sync',
                              ),
                              hugeIcon(
                                'server',
                                className:
                                    'w-4 h-4 text-teal-600 dark:text-teal-400',
                              ),
                            ],
                          ),
                          P(
                            className:
                                'text-xs text-slate-500 dark:text-slate-400 '
                                'leading-relaxed',
                            text:
                                '142 global nodes synchronized with automatic '
                                'HTTP/3 fallback.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            }

            // Webhooks / Event Stream Tab
            return Div(
              className: 'space-y-4',
              children: [
                Div(
                  className:
                      'text-xs font-mono text-slate-500 dark:text-slate-400 '
                      'uppercase tracking-wider font-bold',
                  text: 'Live Edge Event Stream',
                ),
                Div(
                  className:
                      'p-5 rounded-2xl bg-slate-950 dark:bg-black border '
                      'border-slate-800 dark:border-zinc-800 font-mono text-xs '
                      'text-slate-300 space-y-2 max-h-60 overflow-y-auto shadow-xl',
                  children: [
                    for (final log in logs.value)
                      Div(
                        className:
                            'flex items-center gap-2 text-[11px] leading-relaxed',
                        children: [
                          Span(className: 'text-blue-400 font-bold', text: '>'),
                          Span(
                            className: log.contains('SUCCESS')
                                ? 'text-emerald-400 font-bold'
                                : log.contains('WARN')
                                ? 'text-rose-400 font-bold'
                                : 'text-slate-300',
                            text: log,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    ],
  );
}
