import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/hero_video_bg.dart';
import '../components/huge_icons.dart';
import '../components/interactive/bloom_query_playground.dart';
import '../components/interactive/boot_di_visualizer.dart';
import '../components/interactive/build_architecture_playground.dart';
import '../components/interactive/file_system_tree_explorer.dart';
import '../components/interactive/signals_simulator.dart';
import 'page_layout.dart';

BloomNode buildPage() {
  return pageLayout(
    currentPath: '/build',
    petalHighlight: 'purple',
    nextChapterTitle: 'SHIP — Cloud OTA Delivery',
    nextChapterLink: '/ship',
    nextChapterSubtitle:
        'Deploy instant over-the-air byte patches to iOS & Android '
        'devices without app store reviews.',
    child: Div(
      className: 'relative space-y-24 pb-20',
      children: [
        // 1. Hero Section
        Section(
          className:
              'pt-16 pb-16 lg:pt-24 lg:pb-20 relative overflow-hidden '
              'text-center',
          children: [
            heroVideoBg(mode: 'build'),
            Div(
              className: 'max-w-4xl mx-auto space-y-6 relative z-10 px-4',
              children: [
                H1(
                  className:
                      'text-4xl sm:text-6xl lg:text-7xl font-black '
                      'tracking-tight text-slate-900 dark:text-white '
                      'leading-[1.1]',
                  children: [
                    const Text('Opinionated Architecture.'),
                    El('br'),
                    Span(
                      className: 'text-gradient-silver',
                      text: 'File-based Routing & Signals for Flutter.',
                    ),
                  ],
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-lg sm:text-xl '
                      'max-w-3xl mx-auto leading-relaxed',
                  text:
                      'Stop arguing over directory structures and state packages. '
                      'Bloom brings Next.js-style file-system routing, signals '
                      'reactivity, dependency injection, and automated code '
                      'generation to Flutter.',
                ),
              ],
            ),
            Div(
              className: 'mt-14 max-w-6xl mx-auto px-4',
              children: [buildArchitecturePlayground()],
            ),
          ],
        ),

        // 2. Boot & DI Architecture
        Section(
          attrs: const {'id': 'boot-di'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Thin Boot Sequence & Dependency Injection',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Bloom handles environment initialization, DI container '
                      'registration, and app lifecycle prior to `runApp()`.',
                ),
              ],
            ),
            bootDIVisualizer(),
          ],
        ),

        // 3. State Management (Signals) Section
        Section(
          attrs: const {'id': 'signals-state'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Fine-Grained Reactivity with Signals',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Say goodbye to verbose state containers. Signals track '
                      'dependencies automatically, rebuilding only the exact '
                      'widgets reading their value.',
                ),
              ],
            ),
            signalsReactivitySimulator(),
          ],
        ),

        // 4. Bloom Query (Declarative Data Fetching) Section
        Section(
          attrs: const {'id': 'bloom-query'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Declarative Data Fetching with Bloom Query',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Manage server state, caching, refetching, and pagination '
                      'out of the box with zero boilerplate.',
                ),
              ],
            ),
            bloomQueryPlayground(),
          ],
        ),

        // 5. Deep Architecture (File-System Routing Engine)
        Section(
          attrs: const {'id': 'file-routing'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Zero-Boilerplate Routing Engine',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Directory structure *is* your routing tree. Group routes, '
                      'protect layouts with guards, and capture dynamic URL '
                      'parameters seamlessly.',
                ),
              ],
            ),
            fileSystemTreeExplorer(),
          ],
        ),

        // 6. Closing 3-Card Grid
        Section(
          className: 'max-w-5xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'grid grid-cols-1 md:grid-cols-3 gap-6',
              children: [
                Div(
                  className:
                      'p-6 rounded-2xl bg-white/60 dark:bg-zinc-900/60 border '
                      'border-slate-200/80 dark:border-zinc-800 backdrop-blur-xl '
                      'space-y-3',
                  children: [
                    hugeIcon('zap', className: 'w-6 h-6 text-slate-500 dark:text-slate-400 mb-4'),
                    H3(
                      className:
                          'text-lg font-bold text-slate-900 dark:text-white mb-2',
                      text: 'Signals Reactive State',
                    ),
                    P(
                      className:
                          'text-xs text-slate-600 dark:text-slate-400 '
                          'leading-relaxed',
                      text:
                          'Fine-grained state updates with zero `setState` or '
                          'verbose Bloc boilerplate. Rebuilds only the exact '
                          'widgets reading the signal.',
                    ),
                  ],
                ),
                Div(
                  className:
                      'p-6 rounded-2xl bg-white/60 dark:bg-zinc-900/60 border '
                      'border-slate-200/80 dark:border-zinc-800 backdrop-blur-xl '
                      'space-y-3',
                  children: [
                    hugeIcon('cpu', className: 'w-6 h-6 text-slate-500 dark:text-slate-400 mb-4'),
                    H3(
                      className:
                          'text-lg font-bold text-slate-900 dark:text-white mb-2',
                      text: 'CLI Code Generation',
                    ),
                    P(
                      className:
                          'text-xs text-slate-600 dark:text-slate-400 '
                          'leading-relaxed',
                      text:
                          'Generates route tables, typed navigation extensions, '
                          'and data models automatically on file save.',
                    ),
                  ],
                ),
                Div(
                  className:
                      'p-6 rounded-2xl bg-white/60 dark:bg-zinc-900/60 border '
                      'border-slate-200/80 dark:border-zinc-800 backdrop-blur-xl '
                      'space-y-3',
                  children: [
                    hugeIcon('check-circle', className: 'w-6 h-6 text-slate-500 dark:text-slate-400 mb-4'),
                    H3(
                      className:
                          'text-lg font-bold text-slate-900 dark:text-white mb-2',
                      text: 'Nested Layouts',
                    ),
                    P(
                      className:
                          'text-xs text-slate-600 dark:text-slate-400 '
                          'leading-relaxed',
                      text:
                          'Persist sidebars, bottom navigation, and search bars '
                          'across route changes without losing component state.',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
