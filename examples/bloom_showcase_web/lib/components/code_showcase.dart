import 'package:bloom_js_native/bloom_js_native.dart';
import '../state/showcase_store.dart';

class CodeShowcaseComponent {
  final ShowcaseStore store;
  CodeShowcaseComponent(this.store);

  BloomNode build() {
    return Section(
      attrs: {'id': 'code'},
      className: 'py-20 px-6 max-w-7xl mx-auto',
      children: [
        // Section Header
        Div(
          className: 'text-center max-w-3xl mx-auto mb-12',
          children: [
            Span(className: 'text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider', text: 'Developer Ergonomics'),
            H2(className: 'text-3xl sm:text-4xl font-bold text-white mt-2 mb-4', text: 'Clean, Declarative Pure Dart'),
            P(className: 'text-zinc-400 text-base leading-relaxed', text: 'No HTML templates, no JSX, and zero dynamic code generation at runtime. Every component is a strongly-typed, tree-shakeable AST descriptor tree.'),
          ],
        ),

        // Terminal Window
        Div(
          className: 'max-w-4xl mx-auto rounded-2xl bg-[#09090B] border border-[#1E1E24] shadow-2xl overflow-hidden',
          children: [
            // Window Header with Tabs
            Div(
              className: 'px-4 py-3 bg-[#101014] border-b border-[#1E1E24] flex items-center justify-between',
              children: [
                // Window Control Dots
                Div(
                  className: 'flex items-center gap-2',
                  children: [
                    Span(className: 'w-3 h-3 rounded-full bg-[#EF4444]/80 border border-[#DC2626]'),
                    Span(className: 'w-3 h-3 rounded-full bg-[#F59E0B]/80 border border-[#D97706]'),
                    Span(className: 'w-3 h-3 rounded-full bg-[#10B981]/80 border border-[#059669]'),
                  ],
                ),

                // Code Tabs
                Div(
                  className: 'flex items-center gap-2',
                  children: [
                    _tabButton('main.dart', 'UI Component'),
                    _tabButton('ssr_router.dart', 'Server SSR'),
                    _tabButton('bloom.yaml', 'NPM Toolchain'),
                  ],
                ),

                // Copy Code Button
                Button(
                  className: 'text-xs font-mono px-2.5 py-1 rounded bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A] flex items-center gap-1.5 transition-colors cursor-pointer',
                  onClick: (_) => store.showToast('Snippet copied to clipboard!'),
                  children: [
                    Raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),
                    Span(text: 'Copy'),
                  ],
                ),
              ],
            ),

            // Code Content with Line Numbers & Vivid Syntax Highlighting
            Div(
              className: 'p-6 font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-zinc-300 custom-scrollbar bg-[#09090B]',
              children: [
                Live(() => _renderActiveCode(store.activeTab.value)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _tabButton(String key, String label) {
    return Live(() {
      final isSelected = store.activeTab.value == key;
      return Button(
        className: 'px-3 py-1.5 text-xs font-mono rounded-md transition-all cursor-pointer ${isSelected ? "bg-[#1E1E24] text-white font-semibold shadow-sm border border-[#27272A]" : "text-zinc-500 hover:text-zinc-300"}',
        onClick: (_) => store.selectTab(key),
        text: label,
      );
    });
  }

  BloomNode _renderActiveCode(String tab) {
    switch (tab) {
      case 'ssr_router.dart':
        return Div(
          className: 'flex',
          children: [
            _lineNumbers(18),
            Pre(
              className: 'flex-1 pl-4',
              children: [
                Span(className: 'text-zinc-500 italic', text: '// apps/server/bin/server.dart\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'import'),
                Span(text: ' \'package:bloom_framework/bloom.dart\';\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'import'),
                Span(text: ' \'package:bloom_js_native/bloom_js_native.dart\';\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'import'),
                Span(text: ' \'package:bloom_seo/bloom_seo.dart\';\n\n'),
                Span(className: 'text-[#C084FC] font-bold', text: 'void'),
                Span(text: ' main() {\n'),
                Span(text: '  final router = BloomApiRouter();\n\n'),
                Span(className: 'text-zinc-500 italic', text: '  // Unified Sub-Millisecond SSR Route (<1ms response)\n'),
                Span(text: '  router.ssr(\n'),
                Span(text: '    \'/\',\n'),
                Span(text: '    (req) => Div(\n'),
                Span(text: '      className: \'min-h-screen bg-black text-white p-12\',\n'),
                Span(text: '      children: [\n'),
                Span(text: '        H1(className: \'text-4xl font-bold\', text: \'Bloom SSR\'),\n'),
                Span(text: '        P(text: \'Zero JavaScript loaded on initial paint.\'),\n'),
                Span(text: '      ],\n'),
                Span(text: '    ),\n'),
                Span(text: '    head: (req) => HeadManager(initialTitle: \'Bloom Fast SSR\'),\n'),
                Span(text: '  );\n\n'),
                Span(text: '  router.listen(port: 8080);\n'),
                Span(text: '}\n'),
              ],
            ),
          ],
        );

      case 'bloom.yaml':
        return Div(
          className: 'flex',
          children: [
            _lineNumbers(15),
            Pre(
              className: 'flex-1 pl-4',
              children: [
                Span(className: 'text-zinc-500 italic', text: '# bloom.yaml — Zero Configuration Toolchain\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'name'),
                Span(text: ': showcase_app\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'target'),
                Span(text: ': web_dom\n\n'),
                Span(className: 'text-[#F472B6] font-bold', text: 'npm_packages'),
                Span(text: ':\n'),
                Span(className: 'text-[#38BDF8]', text: '  three'),
                Span(text: ':\n'),
                Span(text: '    npm_name: three\n'),
                Span(text: '    version: 0.160.0\n'),
                Span(text: '    vendor_file: web/vendor/three.min.js\n'),
                Span(text: '    dart_binding: lib/plugins/three_js.dart\n\n'),
                Span(className: 'text-[#38BDF8]', text: '  canvas-confetti'),
                Span(text: ':\n'),
                Span(text: '    npm_name: canvas-confetti\n'),
                Span(text: '    version: 1.9.3\n'),
                Span(text: '    vendor_file: web/vendor/canvas-confetti.min.js\n'),
              ],
            ),
          ],
        );

      default:
        return Div(
          className: 'flex',
          children: [
            _lineNumbers(24),
            Pre(
              className: 'flex-1 pl-4',
              children: [
                Span(className: 'text-zinc-500 italic', text: '// lib/main.dart — Fine-Grained Signals UI\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'import'),
                Span(text: ' \'package:bloom_js_native/bloom_js_native.dart\';\n'),
                Span(className: 'text-[#818CF8] font-bold', text: 'import'),
                Span(text: ' \'package:bloom_js_native/browser.dart\';\n\n'),
                Span(className: 'text-[#C084FC] font-bold', text: 'void'),
                Span(text: ' main() {\n'),
                Span(text: '  final count = signal('),
                Span(className: 'text-[#FBBF24]', text: '0'),
                Span(text: ');\n'),
                Span(text: '  final isEven = computed(() => count.value.isEven);\n\n'),
                Span(text: '  mount(\n'),
                Span(text: '    Div(\n'),
                Span(text: '      className: \'p-6 bg-zinc-950 rounded-2xl border border-zinc-800 max-w-md mx-auto\',\n'),
                Span(text: '      children: [\n'),
                Span(text: '        Live(() => H2(\n'),
                Span(text: '          className: \'text-2xl font-bold text-white\',\n'),
                Span(text: '          text: \'Count: \${count.value} (\${isEven.value ? \"Even\" : \"Odd\"})\',\n'),
                Span(text: '        )),\n'),
                Span(text: '        Button(\n'),
                Span(text: '          className: \'mt-4 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg\',\n'),
                Span(text: '          onClick: (_) => count.value++,\n'),
                Span(text: '          text: \'Increment Signal\',\n'),
                Span(text: '        ),\n'),
                Span(text: '      ],\n'),
                Span(text: '    ),\n'),
                Span(text: '    \'#app\',\n'),
                Span(text: '  );\n'),
                Span(text: '}\n'),
              ],
            ),
          ],
        );
    }
  }

  BloomNode _lineNumbers(int count) {
    return Div(
      className: 'select-none pr-4 text-right border-r border-[#1E1E24] text-zinc-600 font-mono text-xs sm:text-sm',
      children: [
        Pre(
          children: [
            Span(text: List.generate(count, (i) => '${i + 1}'.padLeft(2, ' ')).join('\n')),
          ],
        ),
      ],
    );
  }
}
