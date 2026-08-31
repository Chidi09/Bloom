import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _NodeRegion {
  final String id;
  final String name;
  final String latency;
  final int nodes;
  final String status;
  final String hash;

  const _NodeRegion({
    required this.id,
    required this.name,
    required this.latency,
    required this.nodes,
    required this.status,
    required this.hash,
  });
}

const _regions = <_NodeRegion>[
  _NodeRegion(
    id: 'us-east',
    name: 'US-East (N. Virginia)',
    latency: '8ms',
    nodes: 48,
    status: 'HEALTHY',
    hash: 'sha256_8f9a2b',
  ),
  _NodeRegion(
    id: 'eu-central',
    name: 'EU-Central (Frankfurt)',
    latency: '12ms',
    nodes: 42,
    status: 'HEALTHY',
    hash: 'sha256_8f9a2b',
  ),
  _NodeRegion(
    id: 'ap-south',
    name: 'AP-South (Tokyo)',
    latency: '14ms',
    nodes: 36,
    status: 'HEALTHY',
    hash: 'sha256_8f9a2b',
  ),
  _NodeRegion(
    id: 'sa-east',
    name: 'SA-East (São Paulo)',
    latency: '18ms',
    nodes: 16,
    status: 'HEALTHY',
    hash: 'sha256_8f9a2b',
  ),
];

BloomNode enterpriseOtaTopology() {
  final selectedRegionId = signal('us-east');

  return Div(
    className:
        'p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
        'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl '
        'mx-auto space-y-8 text-left',
    children: [
      // Header & Status
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
                  hugeIcon('server', className: 'w-5 h-5 text-teal-500'),
                  H3(
                    className:
                        'text-xl font-bold text-slate-900 dark:text-white '
                        'tracking-tight',
                    text:
                        'Global 142-Edge Node Topology & RSA-2048 Security Engine',
                  ),
                ],
              ),
              P(
                className: 'text-xs text-slate-600 dark:text-slate-400',
                text:
                    'Click region clusters to inspect real-time Edge CDN delivery '
                    'latency and RSA-2048 cryptographic signatures.',
              ),
            ],
          ),
          Div(
            className:
                'px-3 py-1 rounded-full bg-emerald-500/15 text-emerald-600 '
                'dark:text-emerald-400 font-mono text-xs font-bold border '
                'border-emerald-500/30 flex items-center gap-1.5 shrink-0',
            children: [
              Span(
                className: 'w-2 h-2 rounded-full bg-emerald-500 animate-pulse',
              ),
              const Text('142 NODES ONLINE'),
            ],
          ),
        ],
      ),

      // Region Cluster Grid
      Div(
        className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4',
        children: [
          for (final r in _regions)
            Live(() {
              final isSelected = selectedRegionId.value == r.id;
              return Button(
                attrs: {'type': 'button'},
                onClick: (_) => selectedRegionId.value = r.id,
                className:
                    'p-5 rounded-2xl text-left transition-all duration-300 '
                    'border cursor-pointer ${isSelected ? 'bg-slate-900 text-white dark:bg-zinc-900 dark:border-white shadow-xl scale-105' : 'bg-slate-50 dark:bg-zinc-950 border-slate-200 dark:border-zinc-800 text-slate-900 dark:text-white hover:border-teal-500'}',
                children: [
                  Div(
                    className: 'flex items-center justify-between mb-3',
                    children: [
                      Span(
                        className:
                            'text-[10px] font-mono font-bold text-slate-500 '
                            'dark:text-slate-400',
                        text: '${r.nodes} Edge Nodes',
                      ),
                      Span(
                        className:
                            'text-xs font-mono font-black text-teal-600 '
                            'dark:text-teal-400',
                        text: r.latency,
                      ),
                    ],
                  ),
                  Div(className: 'text-xs font-bold mb-1', text: r.name),
                  Div(
                    className:
                        'text-[11px] font-mono text-emerald-600 '
                        'dark:text-emerald-400 flex items-center gap-1',
                    children: [
                      hugeIcon('check-circle', className: 'w-3.5 h-3.5'),
                      Span(text: r.status),
                    ],
                  ),
                ],
              );
            }),
        ],
      ),

      // Detail Inspector Card
      Div(
        className:
            'p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
            'border-slate-200 dark:border-zinc-800 flex flex-col sm:flex-row '
            'items-start sm:items-center justify-between gap-6 font-mono text-xs '
            'shadow-inner',
        children: [
          Div(
            className: 'space-y-1',
            children: [
              Span(
                className:
                    'text-[10px] text-slate-500 dark:text-slate-400 font-bold '
                    'block',
                text: 'CRYPTOGRAPHIC VERIFICATION',
              ),
              Div(
                className:
                    'flex items-center gap-2 text-slate-900 dark:text-white '
                    'font-bold',
                children: [
                  hugeIcon(
                    'sparkles',
                    className: 'w-4 h-4 text-purple-600 dark:text-purple-400',
                  ),
                  Span(
                    text: 'RSA-2048 Bit Public Key · SHA-256 Digest Signature',
                  ),
                ],
              ),
              P(
                className: 'text-[11px] text-slate-600 dark:text-slate-400',
                text:
                    'Byte-patches verified on device hardware secure enclave '
                    'before loading into memory.',
              ),
            ],
          ),
          Live(() {
            final active = _regions.firstWhere(
              (r) => r.id == selectedRegionId.value,
              orElse: () => _regions.first,
            );

            return Div(
              className:
                  'p-3 bg-white dark:bg-zinc-900 rounded-xl border '
                  'border-slate-200 dark:border-zinc-800 text-slate-700 '
                  'dark:text-slate-300 shrink-0 font-mono text-xs',
              children: [
                Span(
                  className:
                      'text-[10px] text-slate-500 dark:text-slate-400 block '
                      'mb-0.5 font-bold',
                  text: 'ACTIVE CLUSTER DIGEST',
                ),
                Span(
                  className: 'text-purple-600 dark:text-purple-400 font-bold',
                  text: '${active.id} :: ${active.hash}',
                ),
              ],
            );
          }),
        ],
      ),
    ],
  );
}
