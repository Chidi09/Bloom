import 'package:bloom_js_native/bloom_js_native.dart';
import '../state/showcase_store.dart';

class NavbarComponent {
  final ShowcaseStore store;
  NavbarComponent(this.store);

  BloomNode build() {
    return Header(
      className: 'sticky top-0 z-50 w-full border-b border-[#1E1E24] bg-[#09090B]/80 backdrop-blur-md',
      children: [
        Div(
          className: 'max-w-7xl mx-auto px-6 h-16 flex items-center justify-between',
          children: [
            // Left: Logo & Wordmark
            Div(
              className: 'flex items-center gap-3',
              children: [
                Div(
                  className: 'w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500 to-violet-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/20 text-sm tracking-tight',
                  children: [
                    Raw('<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>'),
                  ],
                ),
                Div(
                  className: 'flex items-baseline gap-2',
                  children: [
                    Span(className: 'font-bold text-lg text-white tracking-tight', text: 'Bloom'),
                    Span(className: 'text-xs font-mono px-2 py-0.5 rounded-full bg-[#1E1E24] text-indigo-400 border border-[#27272A]', text: 'JS Native'),
                  ],
                ),
              ],
            ),

            // Center: Nav Links
            Nav(
              className: 'hidden md:flex items-center gap-8 text-sm text-zinc-400 font-medium',
              children: [
                A(href: '#features', className: 'hover:text-white transition-colors', text: 'Architecture'),
                A(href: '#benchmark', className: 'hover:text-white transition-colors', text: 'Telemetry Benchmark'),
                A(href: '#code', className: 'hover:text-white transition-colors', text: 'Code Showcase'),
                A(href: 'https://github.com/Chidi09/Bloom', className: 'hover:text-white transition-colors', text: 'Documentation'),
              ],
            ),

            // Right: Actions
            Div(
              className: 'flex items-center gap-4',
              children: [
                Button(
                  className: 'px-4 py-2 text-xs font-mono rounded-lg bg-[#14141A] hover:bg-[#1E1E24] text-zinc-300 border border-[#27272A] flex items-center gap-2 transition-all cursor-pointer shadow-sm',
                  onClick: (_) => store.triggerCopyCommand(),
                  children: [
                    Raw('<svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),
                    Span(text: 'bloom create'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
