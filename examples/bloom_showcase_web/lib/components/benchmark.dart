import 'package:bloom_js_native/bloom_js_native.dart';
import '../state/showcase_store.dart';

class BenchmarkComponent {
  final ShowcaseStore store;
  BenchmarkComponent(this.store);

  BloomNode build() {
    return Section(
      attrs: {'id': 'benchmark'},
      className: 'py-20 px-6 max-w-7xl mx-auto',
      children: [
        // Section Header
        Div(
          className: 'text-center max-w-3xl mx-auto mb-12',
          children: [
            Span(className: 'text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider', text: 'Real-Time Telemetry & Comparative Benchmarks'),
            H2(className: 'text-3xl sm:text-4xl font-bold text-white mt-2 mb-4', text: 'Fine-Grained Signals vs VDOM Diffing'),
            P(className: 'text-zinc-400 text-base leading-relaxed', text: 'Unlike React or Flutter which recreate virtual element trees on every state change, Bloom binds signals directly to individual DOM text nodes and attributes with zero reconciliation overhead.'),
          ],
        ),

        // Live Benchmark Console Card
        Div(
          className: 'rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl overflow-hidden mb-12',
          children: [
            // Top Controls Bar
            Div(
              className: 'flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-[#1E1E24]',
              children: [
                // Left: Controls
                Div(
                  className: 'flex items-center gap-4 flex-wrap',
                  children: [
                    Button(
                      className: 'px-4 py-2.5 rounded-lg font-medium text-xs flex items-center gap-2 cursor-pointer transition-all bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/20 active:scale-95',
                      onClick: (_) => store.toggleBenchmark(),
                      children: [
                        Live(() => store.isBenchmarking.value
                            ? Raw('<svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>')
                            : Raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>')),
                        Live(() => Span(text: store.isBenchmarking.value ? 'Pause Stress Ticker' : 'Run Live Stress Ticker')),
                      ],
                    ),
                    Div(
                      className: 'flex items-center gap-3 bg-[#14141A] px-4 py-2 rounded-lg border border-[#27272A]',
                      children: [
                        Span(className: 'text-xs text-zinc-400 font-mono', text: 'Nodes:'),
                        Live(() => Span(className: 'text-xs font-mono font-bold text-white', text: '${store.nodeCount.value}')),
                        Button(
                          className: 'px-2 py-0.5 rounded bg-[#1E1E24] hover:bg-[#27272A] text-xs font-mono text-zinc-300 cursor-pointer',
                          onClick: (_) => store.updateNodeCount((store.nodeCount.value - 12).clamp(12, 120)),
                          text: '-',
                        ),
                        Button(
                          className: 'px-2 py-0.5 rounded bg-[#1E1E24] hover:bg-[#27272A] text-xs font-mono text-zinc-300 cursor-pointer',
                          onClick: (_) => store.updateNodeCount((store.nodeCount.value + 12).clamp(12, 120)),
                          text: '+',
                        ),
                      ],
                    ),
                  ],
                ),

                // Right: Real-Time Telemetry Stats
                Div(
                  className: 'flex items-center gap-6 font-mono text-xs',
                  children: [
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        Span(className: 'w-2 h-2 rounded-full bg-emerald-400 animate-pulse'),
                        Span(className: 'text-zinc-400', text: 'FPS:'),
                        Live(() => Span(className: 'text-emerald-400 font-bold', text: '${store.fps.value}')),
                      ],
                    ),
                    Div(
                      className: 'flex items-center gap-2',
                      children: [
                        Span(className: 'w-2 h-2 rounded-full bg-indigo-400'),
                        Span(className: 'text-zinc-400', text: 'Patch Latency:'),
                        Live(() => Span(className: 'text-indigo-400 font-bold', text: '${store.patchLatencyMs.value} ms')),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Reactive Node Grid (Stress Display)
            Div(
              className: 'pt-6',
              children: [
                Div(
                  className: 'grid grid-cols-3 sm:grid-cols-6 md:grid-cols-12 gap-2.5',
                  children: [
                    Live(() => Fragment.fromList(
                      store.benchmarkItems.value.map((item) => Div(
                        className: 'p-3 rounded-lg bg-[#14141A] border border-[#27272A] flex flex-col items-center justify-center transition-colors shadow-sm',
                        children: [
                          Span(className: 'text-[10px] font-mono text-zinc-500', text: '#$item'),
                          Span(className: 'text-sm font-mono font-bold text-indigo-400 mt-1', text: '${(item * 137) % 999}'),
                        ],
                      )).toList(),
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Live Chart.js Comparative Performance Canvas Card
        Div(
          className: 'rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl',
          children: [
            Div(
              className: 'flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6',
              children: [
                Div(
                  children: [
                    H3(className: 'text-lg font-bold text-white', text: 'Benchmark Matrix: Web Frameworks Comparison'),
                    P(className: 'text-xs text-zinc-400 mt-0.5', text: 'Independent cold-start SSR latency and production JS gzip footprint benchmarks.'),
                  ],
                ),
                Span(className: 'text-xs font-mono px-3 py-1 rounded-full bg-[#14141A] text-indigo-400 border border-[#27272A]', text: 'Chart.js Native Binding'),
              ],
            ),
            Div(
              className: 'h-72 w-full relative',
              children: [
                Raw('<canvas id="perf-chart" class="w-full h-full"></canvas>'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
