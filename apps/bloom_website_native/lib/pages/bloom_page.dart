import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/common/orchestration_flow.dart';
import '../components/hero_video_bg.dart';
import '../components/huge_icons.dart';
import '../components/interactive/ui_studio_picker.dart';
import 'page_layout.dart';

BloomNode bloomPage() {
  return pageLayout(
    currentPath: '/bloom',
    petalHighlight: 'all',
    nextChapterTitle: 'BUILD — Framework & DX',
    nextChapterLink: '/build',
    nextChapterSubtitle:
        'Return to chapter 01 to explore opinionated file-based routing '
        'and reactive signals.',
    child: Div(
      className: 'relative space-y-24 pb-20',
      children: [
        // 1. Hero Section
        Section(
          className:
              'pt-16 pb-12 lg:pt-24 lg:pb-16 relative overflow-hidden '
              'text-center',
          children: [
            heroVideoBg(mode: 'bloom'),
            Div(
              className: 'max-w-4xl mx-auto space-y-6 relative z-10 px-4',
              children: [
                H1(
                  className:
                      'text-4xl sm:text-6xl lg:text-7xl font-black '
                      'tracking-tight text-slate-900 dark:text-white '
                      'leading-[1.1]',
                  children: [
                    const Text('Bloom UI Studio.'),
                    El('br'),
                    Span(
                      className: 'text-gradient-silver',
                      text: 'shadcn/ui for Flutter Mobile.',
                    ),
                  ],
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-lg sm:text-xl '
                      'max-w-2xl mx-auto leading-relaxed',
                  text:
                      'Beautifully designed, accessible mobile components. '
                      'Customize design tokens below and watch buttons, inputs, '
                      'wallet cards, badges, and bottom bars update in real time.',
                ),
                Div(
                  className:
                      'flex flex-wrap items-center justify-center gap-4 pt-2',
                  children: [
                    A(
                      href: '/blocks',
                      className:
                          'flex items-center gap-2 px-6 py-3 rounded-2xl '
                          'bg-gradient-to-r from-pink-500 via-purple-500 '
                          'to-cyan-500 text-white text-xs font-bold shadow-lg '
                          'hover:shadow-purple-500/25 hover:scale-[1.02] '
                          'transition-all',
                      children: [
                        hugeIcon('sparkles', className: 'w-4 h-4 text-white'),
                        const Text('Browse All 60+ Components'),
                        hugeIcon('arrow-right', className: 'w-4 h-4 ml-1'),
                      ],
                    ),
                    A(
                      href: 'https://pub.dev/packages/bloom_ui',
                      attrs: const {'target': '_blank'},
                      className:
                          'flex items-center gap-2 px-5 py-3 rounded-2xl '
                          'bg-slate-100 dark:bg-zinc-950 border border-slate-300 '
                          'dark:border-zinc-800 text-slate-800 dark:text-slate-200 '
                          'text-xs font-bold hover:bg-slate-200 '
                          'dark:hover:bg-zinc-800 transition',
                      children: const [Text('bloom_ui v0.1.0 on pub.dev')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // 2. Interactive UI Studio Picker Section (#studio-picker)
        Section(
          attrs: const {'id': 'studio-picker'},
          className: 'max-w-[90rem] mx-auto px-4 sm:px-6 lg:px-8 pt-0',
          children: [
            Div(
              className: 'max-w-[90rem] mx-auto flex justify-center',
              children: [uiStudioPicker()],
            ),
          ],
        ),

        // 3. Framework Pipeline Flow (#pipeline-flow)
        Section(
          attrs: const {'id': 'pipeline-flow'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-12',
              children: [
                Div(
                  className:
                      'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                      'glass-panel text-xs font-mono font-bold text-slate-600 '
                      'dark:text-slate-400',
                  children: [
                    hugeIcon('sparkles', className: 'w-3.5 h-3.5'),
                    const Text('Framework Pipeline Flow'),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Standardize → Wrap → Generate → Orchestrate',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'How Bloom takes mature Dart & Flutter infrastructure and '
                      'delivers a seamless mobile experience.',
                ),
              ],
            ),
            orchestrationFlow(),
          ],
        ),

        // 4. Production-Ready Mobile Architecture Grid
        Section(
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                H2(
                  className:
                      'text-3xl sm:text-4xl font-black text-slate-900 '
                      'dark:text-white',
                  text: 'Production-Ready Mobile Architecture',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Built natively for Flutter Mobile, Tablet & Web with '
                      'zero compromise on accessibility or performance.',
                ),
              ],
            ),
            Div(
              className:
                  'grid grid-cols-1 md:grid-cols-3 gap-8 max-w-5xl mx-auto',
              children: [
                _renderStudioFeatureCard(
                  icon: 'folder',
                  title: 'shadcn Architecture',
                  desc:
                      'Copy-paste source code directly into your Flutter '
                      'project. You own every line of code with complete styling '
                      'control.',
                ),
                _renderStudioFeatureCard(
                  icon: 'check-circle',
                  title: 'Accessible Primitives',
                  desc:
                      'Keyboard navigation, focus traps, screen reader '
                      'semantics, and WCAG AA contrast built in out of the box.',
                ),
                _renderStudioFeatureCard(
                  icon: 'sparkles',
                  title: 'Fluid Micro-Animations',
                  desc:
                      'Subtle spring physics, hover glows, and press states '
                      'crafted with 60fps Flutter Impeller rendering.',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

BloomNode _renderStudioFeatureCard({
  required String icon,
  required String title,
  required String desc,
}) {
  return Div(
    className:
        'p-8 rounded-3xl glass-panel border border-slate-200/80 '
        'dark:border-zinc-800 transition duration-300 hover:border-purple-500/40 '
        'text-left space-y-3',
    children: [
      hugeIcon(
        icon,
        className: 'w-8 h-8 text-slate-500 dark:text-slate-400 mb-4',
      ),
      H3(
        className: 'text-xl font-bold text-slate-900 dark:text-white mb-2',
        text: title,
      ),
      P(
        className:
            'text-xs text-slate-600 dark:text-slate-400 '
            'leading-relaxed font-sans',
        text: desc,
      ),
    ],
  );
}
