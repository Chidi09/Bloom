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
            P(className: 'text-zinc-400 text-base leading-relaxed', text: 'No HTML templates, no JSX, and zero dynamic code generation at runtime. Every component is a strongly-typed AST descriptor tree.'),
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
                // Window Buttons
                Div(
                  className: 'flex items-center gap-2',
                  children: [
                    Span(className: 'w-3 h-3 rounded-full bg-[#27272A]'),
                    Span(className: 'w-3 h-3 rounded-full bg-[#27272A]'),
                    Span(className: 'w-3 h-3 rounded-full bg-[#27272A]'),
                  ],
                ),

                // Code Tabs
                Div(
                  className: 'flex items-center gap-2',
                  children: [
                    _tabButton('main.dart', 'UI Component'),
                    _tabButton('ssr_router.dart', 'Server SSR'),
                    _tabButton('bloom.yaml', 'NPM Config'),
                  ],
                ),

                // Language Tag
                Span(className: 'text-[11px] font-mono text-zinc-500 hidden sm:block', text: 'Dart 3.5'),
              ],
            ),

            // Code Content
            Div(
              className: 'p-6 font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-zinc-300 custom-scrollbar',
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
        className: 'px-3 py-1 text-xs font-mono rounded-md transition-all cursor-pointer ${isSelected ? "bg-[#1E1E24] text-white font-medium shadow-sm border border-[#27272A]" : "text-zinc-500 hover:text-zinc-300"}',
        onClick: (_) => store.selectTab(key),
        text: label,
      );
    });
  }

  BloomNode _renderActiveCode(String tab) {
    switch (tab) {
      case 'ssr_router.dart':
        return Pre(
          children: [
            Span(className: 'text-zinc-500', text: '// apps/server/bin/server.dart\n'),
            Span(className: 'text-indigo-400', text: 'import'),
            Span(text: ' \'package:bloom_framework/bloom.dart\';\n'),
            Span(className: 'text-indigo-400', text: 'import'),
            Span(text: ' \'package:bloom_js_native/bloom_js_native.dart\';\n\n'),
            Span(className: 'text-violet-400', text: 'void'),
            Span(text: ' main() {\n'),
            Span(text: '  final router = BloomApiRouter();\n\n'),
            Span(className: 'text-zinc-500', text: '  // High-throughput SSR endpoint (<1ms response)\n'),
            Span(text: '  router.ssr(\'/\', (req) => Div(\n'),
            Span(text: '    className: \'min-h-screen bg-black text-white\',\n'),
            Span(text: '    children: [\n'),
            Span(text: '      H1(text: \'Welcome to Bloom\'),\n'),
            Span(text: '      P(text: \'Zero JS baseline loaded statically.\'),\n'),
            Span(text: '    ],\n'),
            Span(text: '  ));\n\n'),
            Span(text: '  router.listen(port: 8080);\n'),
            Span(text: '}\n'),
          ],
        );
      case 'bloom.yaml':
        return Pre(
          children: [
            Span(className: 'text-zinc-500', text: '# bloom.yaml\n'),
            Span(className: 'text-indigo-400', text: 'name'),
            Span(text: ': showcase_app\n'),
            Span(className: 'text-indigo-400', text: 'target'),
            Span(text: ': web_dom\n\n'),
            Span(className: 'text-violet-400', text: 'npm_packages'),
            Span(text: ':\n'),
            Span(text: '  three:\n'),
            Span(text: '    npm_name: three\n'),
            Span(text: '    version: 0.160.0\n'),
            Span(text: '    vendor_file: web/vendor/three.min.js\n'),
            Span(text: '  canvas-confetti:\n'),
            Span(text: '    npm_name: canvas-confetti\n'),
            Span(text: '    version: 1.9.3\n'),
            Span(text: '    vendor_file: web/vendor/canvas-confetti.min.js\n'),
          ],
        );
      default:
        return Pre(
          children: [
            Span(className: 'text-zinc-500', text: '// lib/main.dart\n'),
            Span(className: 'text-indigo-400', text: 'import'),
            Span(text: ' \'package:bloom_js_native/bloom_js_native.dart\';\n'),
            Span(className: 'text-indigo-400', text: 'import'),
            Span(text: ' \'package:bloom_js_native/browser.dart\';\n\n'),
            Span(className: 'text-violet-400', text: 'void'),
            Span(text: ' main() {\n'),
            Span(text: '  final count = signal(0);\n'),
            Span(text: '  final isEven = computed(() => count.value.isEven);\n\n'),
            Span(text: '  mount(\n'),
            Span(text: '    Div(\n'),
            Span(text: '      className: \'p-6 bg-zinc-900 rounded-xl border border-zinc-800\',\n'),
            Span(text: '      children: [\n'),
            Span(text: '        Live(() => H2(text: \'Count: \${count.value}\')),\n'),
            Span(text: '        Button(\n'),
            Span(text: '          className: \'px-4 py-2 bg-indigo-600 rounded text-white\',\n'),
            Span(text: '          onClick: (_) => count.value++,\n'),
            Span(text: '          text: \'Increment\',\n'),
            Span(text: '        ),\n'),
            Span(text: '      ],\n'),
            Span(text: '    ),\n'),
            Span(text: '    \'#app\',\n'),
            Span(text: '  );\n'),
            Span(text: '}\n'),
          ],
        );
    }
  }
}
