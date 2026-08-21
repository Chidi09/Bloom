import 'package:bloom_js_native/bloom_js_native.dart';
import '../state/showcase_store.dart';

class HeroComponent {
  final ShowcaseStore store;
  HeroComponent(this.store);

  BloomNode build() {
    return Section(
      className: 'relative pt-24 pb-20 px-6 overflow-hidden',
      children: [
        // 3D Canvas Background Container
        Div(
          className: 'absolute inset-0 pointer-events-none flex items-center justify-center opacity-60',
          children: [
            Raw('<canvas id="three-hero-canvas" class="w-full h-full max-w-5xl max-h-[600px]"></canvas>'),
          ],
        ),

        // Hero Content
        Div(
          className: 'relative max-w-5xl mx-auto text-center flex flex-col items-center z-10',
          children: [
            // Pill Badge
            Div(
              className: 'inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#14141A] border border-[#27272A] text-xs font-medium text-zinc-300 mb-8 shadow-sm',
              children: [
                Span(className: 'w-2 h-2 rounded-full bg-indigo-500 animate-pulse'),
                Span(text: 'Bloom JS Native — Fine-Grained Web Architecture for Dart'),
              ],
            ),

            // Headline
            H1(
              className: 'text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-white mb-6 leading-[1.1]',
              children: [
                Span(text: 'Pure Dart on the DOM.\n'),
                Span(
                  className: 'bg-gradient-to-r from-indigo-400 via-violet-400 to-indigo-200 bg-clip-text text-transparent',
                  text: '0kB Flutter Runtime.',
                ),
              ],
            ),

            // Subtitle
            P(
              className: 'max-w-2xl text-lg sm:text-xl text-zinc-400 mb-10 leading-relaxed font-normal',
              text: 'Dart owns reactivity, compilation, and tooling. The browser owns rendering. Surgical ESM imports via Bun with sub-millisecond SSR execution.',
            ),

            // Interactive CLI Box & Buttons
            Div(
              className: 'flex flex-col sm:flex-row items-center gap-4 mb-16 w-full justify-center',
              children: [
                // Copy Command Box
                Button(
                  className: 'group px-5 py-3.5 rounded-xl bg-[#14141A] hover:bg-[#1E1E24] border border-[#27272A] hover:border-indigo-500/50 flex items-center gap-3 transition-all cursor-pointer shadow-lg shadow-black/40',
                  onClick: (_) => store.triggerCopyCommand(),
                  children: [
                    Span(className: 'text-xs font-mono text-zinc-500 select-none', text: '\$'),
                    Span(className: 'text-sm font-mono text-zinc-200', text: 'bloom create my_app --target=web_dom'),
                    Live(() => store.isCopied.value
                        ? Raw('<svg class="w-4 h-4 text-emerald-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>')
                        : Raw('<svg class="w-4 h-4 text-zinc-400 group-hover:text-white ml-2 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>')),
                  ],
                ),

                // Star on GitHub Link
                A(
                  href: 'https://github.com/Chidi09/Bloom',
                  className: 'px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/25 cursor-pointer',
                  children: [
                    Raw('<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/></svg>'),
                    Span(text: 'Star on GitHub'),
                  ],
                ),
              ],
            ),

            // 4 Metrics Grid
            Div(
              className: 'grid grid-cols-2 sm:grid-cols-4 gap-4 w-full pt-8 border-t border-[#1E1E24]',
              children: [
                _metricCard('< 1ms', 'SSR HTML Baseline', 'text-indigo-400'),
                _metricCard('82 kB', 'Production Bundle', 'text-violet-400'),
                _metricCard('0 kB', 'Flutter Engine', 'text-cyan-400'),
                _metricCard('100%', 'Fine-Grained Signals', 'text-emerald-400'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _metricCard(String value, String label, String valueColor) {
    return Div(
      className: 'p-4 rounded-xl bg-[#101014] border border-[#1E1E24] text-center flex flex-col items-center justify-center',
      children: [
        Span(className: 'text-2xl sm:text-3xl font-extrabold font-mono mb-1 $valueColor', text: value),
        Span(className: 'text-xs text-zinc-400 font-medium', text: label),
      ],
    );
  }
}
