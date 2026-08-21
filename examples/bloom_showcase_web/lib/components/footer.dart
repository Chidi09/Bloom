import 'package:bloom_js_native/bloom_js_native.dart';

class FooterComponent {
  BloomNode build() {
    return Footer(
      className: 'w-full border-t border-[#1E1E24] bg-[#060608] py-12 px-6',
      children: [
        Div(
          className: 'max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6 text-sm text-zinc-500',
          children: [
            // Left: Wordmark & Info
            Div(
              className: 'flex items-center gap-4',
              children: [
                Span(className: 'font-semibold text-zinc-300 font-mono', text: 'Bloom JS Native'),
                Span(className: 'text-zinc-600', text: '•'),
                Span(text: 'MIT Open Source Framework'),
              ],
            ),

            // Center: System Status
            Div(
              className: 'inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#101014] border border-[#1E1E24] text-xs font-mono text-emerald-400',
              children: [
                Span(className: 'w-2 h-2 rounded-full bg-emerald-500 animate-pulse'),
                Span(text: 'Runtime Status: Nominal (<1ms SSR)'),
              ],
            ),

            // Right: Links
            Div(
              className: 'flex items-center gap-6',
              children: [
                A(href: 'https://github.com/Chidi09/Bloom', className: 'hover:text-white transition-colors', text: 'GitHub'),
                A(href: 'https://github.com/Chidi09/Bloom/tree/main/packages/bloom_js_native', className: 'hover:text-white transition-colors', text: 'Docs'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
