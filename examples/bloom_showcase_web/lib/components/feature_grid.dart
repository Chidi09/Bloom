import 'package:bloom_js_native/bloom_js_native.dart';

class FeatureGridComponent {
  BloomNode build() {
    return Section(
      attrs: {'id': 'features'},
      className: 'py-20 px-6 max-w-7xl mx-auto',
      children: [
        // Section Header
        Div(
          className: 'text-center max-w-3xl mx-auto mb-16',
          children: [
            Span(className: 'text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider', text: 'Core Architecture'),
            H2(className: 'text-3xl sm:text-4xl font-bold text-white mt-2 mb-4', text: 'Engineered for Zero Overhead'),
            P(className: 'text-zinc-400 text-base leading-relaxed', text: 'A web-first framework written in Dart that compiles pure AST descriptors directly to the DOM and server SSR without canvas or virtual DOM bloat.'),
          ],
        ),

        // Grid
        Div(
          className: 'grid grid-cols-1 md:grid-cols-2 gap-6',
          children: [
            _card(
              title: 'Dual-Backend SSR & Instant Hydration',
              tag: 'Sub-Millisecond',
              description: 'The exact same Dart AST descriptors execute in <1ms on server isolates to output SEO-optimized static HTML, then seamlessly activate fine-grained signal subscriptions in the browser.',
              iconSvg: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',
            ),
            _card(
              title: 'Keyed DOM List Reconciliation',
              tag: 'Zero DOM Tear-down',
              description: 'ForEachNode uses active key registries to reuse existing DOM elements on list updates, preserving input focus, scroll positions, and native CSS transitions during high-throughput mutations.',
              iconSvg: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',
            ),
            _card(
              title: 'Bun ESM Toolchain Orchestration',
              tag: 'NPM Native',
              description: 'Consume any of the 2.5M+ NPM packages surgically. The Bloom CLI runs Bun to extract ESM bundles into web/vendor/ and manages browser import maps automatically with CDN fallback.',
              iconSvg: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>',
            ),
            _card(
              title: 'Next.js File-Based Page Routing',
              tag: 'Standardized DX',
              description: 'Organize pages naturally in lib/routes/ with automatic parameter parsing ([slug].dart), nested layout cascades (_layout.dart), and dedicated 404 boundaries (_error.dart).',
              iconSvg: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/>',
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _card({
    required String title,
    required String tag,
    required String description,
    required String iconSvg,
  }) {
    return Div(
      className: 'group p-8 rounded-2xl bg-[#101014] border border-[#1E1E24] hover:border-indigo-500/40 transition-all duration-300 relative overflow-hidden flex flex-col justify-between shadow-lg',
      children: [
        Div(
          children: [
            Div(
              className: 'flex items-center justify-between mb-6',
              children: [
                Div(
                  className: 'w-12 h-12 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-center text-indigo-400 group-hover:text-white group-hover:bg-indigo-600 transition-colors',
                  children: [
                    Raw('<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">$iconSvg</svg>'),
                  ],
                ),
                Span(className: 'text-xs font-mono px-2.5 py-1 rounded-full bg-[#14141A] text-zinc-400 border border-[#27272A]', text: tag),
              ],
            ),
            H3(className: 'text-xl font-bold text-white mb-3 tracking-tight', text: title),
            P(className: 'text-zinc-400 text-sm leading-relaxed', text: description),
          ],
        ),
      ],
    );
  }
}
