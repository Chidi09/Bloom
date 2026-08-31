import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

BloomNode hubFaq() {
  final faqs = const [
    (
      'Is there a full-stack framework for Flutter?',
      'Yes. Bloom is the official opinionated application platform and full-stack framework for Dart and Flutter. It bridges client and backend engineering by unifying backend adapters (Serverpod for end-to-end type-safe Dart RPCs and Supabase for real-time Postgres & Auth), Next.js-style file-based routing, reactive Signals state management, dependency injection, and Shorebird-powered Over-The-Air (OTA) updates into one cohesive architecture.',
    ),
    (
      "How does Bloom's state management compare to Bloc, Riverpod, or Provider?",
      'Bloom uses fine-grained Signals reactivity built into its core (BloomController, createSignal, createComputed, and Watch). Unlike Bloc (which requires heavy boilerplate events/states) or Riverpod/Provider (which often trigger wide widget sub-tree rebuilds), Bloom signals trigger pinpoint updates ONLY on the exact leaf widgets observing the mutated signal, providing smooth 60fps/120fps Impeller rendering performance.',
    ),
    (
      'Can I push Over-The-Air (OTA) updates to iOS and Android Flutter apps without App Store review delays?',
      'Yes. Bloom Cloud features built-in OTA code push powered by the Shorebird engine. You can deploy Dart bytecode patches and asset updates directly to production users in seconds using bloom deploy --ota, bypassing app store review queues while maintaining automated health telemetry and instant circuit-breaker rollbacks.',
    ),
    (
      'How does Next.js-style file-based routing work in Flutter with Bloom?',
      'Simply create files in lib/routes/ (e.g. lib/routes/index.dart for /, lib/routes/users/[id].dart for /users/:id, and lib/routes/(auth)/login.dart for route groups). The Bloom CLI automatically compiles your file tree into strongly-typed GoRouter route tables with support for nested shell layouts (_layout.dart), async route guards, and deep links.',
    ),
    (
      "Does Bloom UI replace Flutter's Material Design or Cupertino?",
      'Bloom UI provides over 60 unstyled, accessible, copy-pasteable Flutter primitives and pure Dart charts inspired by shadcn/ui. Unlike monolithic widget libraries, you own your code: install primitives directly into your codebase with bloom ui add <component> with zero external runtime dependencies and full support for 8 customizable style presets (Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea).',
    ),
    (
      'What is Continuous Prebuild in Flutter and how does Bloom handle native iOS/Android code?',
      'Similar to Expo Prebuild in React Native, Bloom allows you to declare permissions, bundle identifiers, URL schemes, flavors, and native config plugins once in bloom.yaml. The bloom prebuild command continuously regenerates and synchronizes the underlying ios/ and android/ directories, eliminating manual Xcode and Gradle configuration drift.',
    ),
    (
      'Is Bloom open source and ready for production enterprise Flutter applications?',
      'Yes. Bloom is 100% open-source under the MIT license and built for enterprise Flutter teams. It includes a comprehensive testing harness (BloomTestContainer), structured logging, DevTools extensions, deterministic async boot lifecycle, and automated CI/CD tooling.',
    ),
  ];

  return Div(
    className: 'max-w-4xl mx-auto space-y-8',
    children: [
      Div(
        className: 'text-center space-y-4',
        children: [
          Div(
            className:
                'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                'bg-purple-500/10 border border-purple-500/20 '
                'text-purple-400 text-xs font-mono font-bold',
            children: [
              hugeIcon('shield', className: 'w-3.5 h-3.5'),
              Span(text: 'Frequently Asked Questions'),
            ],
          ),
          H2(
            className:
                'text-3xl sm:text-4xl font-black tracking-tight '
                'text-slate-900 dark:text-white',
            text: 'Everything you need to know about Bloom',
          ),
          P(
            className:
                'text-slate-600 dark:text-slate-400 text-sm sm:text-base '
                'max-w-2xl mx-auto',
            text:
                'Common questions about full-stack Flutter development, '
                'file-based routing, OTA code push, and shadcn-style UI '
                'primitives.',
          ),
        ],
      ),

      // FAQ Accordion List
      Div(
        className: 'space-y-4',
        children: [
          for (var i = 0; i < faqs.length; i++)
            El(
              'details',
              className:
                  'group p-6 rounded-2xl sm:rounded-3xl bg-slate-50/60 '
                  'dark:bg-zinc-950/60 border border-slate-200/80 '
                  'dark:border-zinc-800/80 transition-all duration-200 '
                  'hover:border-purple-500/30 backdrop-blur-md',
              attrs: i == 0 ? {'open': 'true'} : null,
              children: [
                El(
                  'summary',
                  className:
                      'flex items-center justify-between gap-4 cursor-pointer '
                      'select-none list-none font-bold text-base sm:text-lg '
                      'text-slate-900 dark:text-white hover:text-purple-600 '
                      'dark:hover:text-purple-400 transition-colors',
                  children: [
                    Span(
                      className: 'flex items-center gap-3',
                      children: [
                        Span(
                          className:
                              'text-xs font-mono text-purple-500 dark:text-purple-400 '
                              'font-normal',
                          text: '0${i + 1}',
                        ),
                        Span(text: faqs[i].$1),
                      ],
                    ),
                    El(
                      'svg',
                      className:
                          'w-5 h-5 text-slate-400 group-open:rotate-180 '
                          'transition-transform duration-200 shrink-0',
                      attrs: {
                        'fill': 'none',
                        'viewBox': '0 0 24 24',
                        'stroke': 'currentColor',
                      },
                      children: [
                        El(
                          'path',
                          attrs: {
                            'stroke-linecap': 'round',
                            'stroke-linejoin': 'round',
                            'stroke-width': '2',
                            'd': 'M19 9l-7 7-7-7',
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Div(
                  className:
                      'pt-4 text-sm sm:text-base text-slate-600 '
                      'dark:text-slate-300 leading-relaxed border-t '
                      'border-slate-200/40 dark:border-zinc-800/60 mt-4',
                  children: [P(text: faqs[i].$2)],
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
