import 'dart:async';
import 'dart:math';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/common/hub_faq.dart';
import '../components/huge_icons.dart';
import '../components/interactive/chapter_cards.dart';
import '../components/interactive/cli_tooling_explorer.dart';
import '../components/interactive/community_showcase.dart';
import '../components/interactive/feature_grid_showcase.dart';
import '../components/interactive/orchestration_pipeline.dart';
import '../components/tech_marquee.dart';
import 'page_layout.dart';

BloomNode homePage() {
  // Static rendering has no client timer, so emit the completed hero first.
  // The browser lifecycle resets it before starting the typewriter animation.
  final typedText = signal('Build.\u00A0Ship.\u00A0Bloom.');
  final isTyping = signal(false);
  final isFinished = signal(true);

  final colors = const ['#FF4B8B', '#FF884D', '#20C9B0', '#3B82F6', '#8B5CF6'];

  final rnd = Random(42);
  final fallingPetals = List.generate(28, (i) {
    final size = rnd.nextDouble() * 45 + 45;
    final left = rnd.nextDouble() * 100;
    final duration = rnd.nextDouble() * 12 + 12;
    final delay = rnd.nextDouble() * -24;
    final startX = '${(rnd.nextDouble() * 60 - 30).toStringAsFixed(1)}px';
    final endX = '${(rnd.nextDouble() * 120 - 60).toStringAsFixed(1)}px';
    final maxOpacity = (rnd.nextDouble() * 0.4 + 0.2).toStringAsFixed(2);
    final rot = '${(rnd.nextDouble() * 720 - 360).toStringAsFixed(1)}deg';
    final color = colors[i % colors.length];
    return (size, left, duration, delay, startX, endX, maxOpacity, rot, color);
  });

  // Typewriter Loop
  const words = ['Build.', 'Ship.', 'Bloom.'];
  int wordIdx = 0;
  int charIdx = 0;
  Timer? typingTimer;

  void schedule(Duration delay, void Function() callback) {
    typingTimer = Timer(delay, callback);
  }

  void typeNext() {
    if (wordIdx < words.length) {
      if (charIdx < words[wordIdx].length) {
        typedText.value = typedText.value + words[wordIdx][charIdx];
        charIdx++;
        schedule(const Duration(milliseconds: 70), typeNext);
      } else {
        if (wordIdx == words.length - 1) {
          isTyping.value = false;
          schedule(const Duration(milliseconds: 300), () {
            isFinished.value = true;
          });
        } else {
          schedule(const Duration(milliseconds: 350), () {
            typedText.value = '${typedText.value}\u00A0';
            wordIdx++;
            charIdx = 0;
            typeNext();
          });
        }
      }
    }
  }

  return Mount(
    pageLayout(
      currentPath: '/',
      nextChapterTitle: 'BUILD — Framework & DX',
      nextChapterLink: '/build',
      nextChapterSubtitle: 'Explore opinionated file-based routing, reactive '
          'signals, and state controllers for Flutter.',
      child: Div(
        className: 'relative',
        children: [
          // 1. Hero Section — Pure Dark Background + Falling Petals (no video on hub)
          Section(
            className: 'pt-16 pb-16 lg:pt-24 lg:pb-20 relative overflow-hidden',
            children: [
              // Falling Petals Background (Hardware Accelerated)
              Div(
                className:
                    'absolute inset-0 overflow-hidden pointer-events-none '
                    '-z-10 select-none',
                children: [
                  for (final (
                        size,
                        left,
                        duration,
                        delay,
                        startX,
                        endX,
                        maxOpacity,
                        rot,
                        color,
                      ) in fallingPetals)
                    Raw('''
<div class="falling-petal" style="left: $left%; width: ${size}px; height: ${size}px; color: $color; animation-duration: ${duration}s; animation-delay: ${delay}s; --start-x: $startX; --end-x: $endX; --max-opacity: $maxOpacity; --rot: $rot;">
  <svg viewBox="0 0 200 200" fill="none" class="w-full h-full opacity-70">
    <path d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z" fill="currentColor" />
  </svg>
</div>
'''),
                ],
              ),

              // Hero Main Content Box
              Div(
                className:
                    'text-center max-w-4xl mx-auto space-y-6 relative z-10 '
                    'min-h-[250px] flex flex-col items-center justify-center',
                children: [
                  // Announcement Pill
                  A(
                    href: 'https://github.com/Chidi09/Bloom',
                    attrs: const {'target': '_blank'},
                    className:
                        'inline-flex flex-wrap items-center justify-center gap-2 '
                        'px-4 py-1.5 rounded-full glass-panel shadow-sm text-xs '
                        'font-medium hover:scale-105 transition cursor-pointer '
                        'group mb-2 max-w-[90vw] text-center',
                    children: [
                      Span(
                        className: 'flex h-2 w-2 relative shrink-0',
                        children: [
                          Span(
                            className:
                                'animate-ping absolute inline-flex h-full w-full '
                                'rounded-full bg-emerald-400 opacity-75',
                          ),
                          Span(
                            className:
                                'relative inline-flex rounded-full h-2 w-2 bg-emerald-500',
                          ),
                        ],
                      ),
                      Span(
                        className: 'text-slate-600 dark:text-slate-300',
                        text:
                            'bloom_ui v0.1.0 published on pub.dev • 60+ shadcn '
                            'primitives for Flutter',
                      ),
                      Span(
                        className:
                            'font-bold text-purple-600 dark:text-purple-400 '
                            'group-hover:text-purple-300 flex items-center gap-1 '
                            'shrink-0',
                        children: [
                          const Text('Explore docs '),
                          hugeIcon(
                            'arrow-right',
                            className: 'w-3.5 h-3.5 group-hover:translate-x-1 '
                                'transition-transform',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Typewriter Hero Header
                  H1(
                    className: 'text-4xl sm:text-6xl lg:text-8xl font-black '
                        'tracking-tighter leading-[1] text-slate-900 '
                        'dark:text-white relative',
                    children: [
                      Live(() {
                        final text = typedText.value;
                        final typing = isTyping.value;
                        return Span(
                          attrs: const {'id': 'heroTypewriter'},
                          className:
                              'text-sweep ${typing ? 'typing-cursor' : ''}',
                          text: text.isEmpty && !typing
                              ? 'Build. Ship. Bloom.'
                              : text,
                        );
                      }),
                    ],
                  ),

                  // Subtitle
                  Live(() {
                    final finished = isFinished.value;
                    return P(
                      attrs: const {'id': 'heroSub'},
                      className:
                          'text-slate-600 dark:text-slate-400 text-base sm:text-xl '
                          'max-w-2xl mx-auto font-normal leading-relaxed '
                          'transition-opacity duration-1000 mt-6 px-2 ${finished ? 'opacity-100' : 'opacity-0'}',
                      text:
                          'The opinionated application platform for Dart & Flutter. '
                          'Standardizing architecture, signals state, go_router '
                          'generation, Shorebird OTA, and Bloom UI.',
                    );
                  }),

                  // Install CLI Bar
                  Live(() {
                    final finished = isFinished.value;
                    return Div(
                      attrs: const {'id': 'heroCmd'},
                      className: 'pt-6 max-w-xl mx-auto transition-opacity '
                          'duration-1000 delay-300 w-full px-2 sm:px-0 space-y-4 ${finished ? 'opacity-100' : 'opacity-0'}',
                      children: [
                        Div(
                          attrs: const {
                            'onclick':
                                "navigator.clipboard.writeText('dart pub global activate bloom_cli'); window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Command Copied', message: 'Run in terminal to install CLI.', type: 'emerald' } }))",
                          },
                          className: 'relative group cursor-pointer w-full',
                          children: [
                            Div(
                              className:
                                  'absolute -inset-1 bg-slate-200/70 dark:bg-white/10 '
                                  'rounded-2xl blur opacity-40 group-hover:opacity-70 '
                                  'transition duration-500',
                            ),
                            Div(
                              className:
                                  'relative glass-panel p-3 sm:p-4 rounded-2xl flex '
                                  'items-center justify-between gap-2 sm:gap-4 '
                                  'overflow-hidden',
                              children: [
                                Div(
                                  className:
                                      'flex items-center gap-2 sm:gap-3 font-mono text-xs '
                                      'sm:text-sm overflow-hidden text-left min-w-0',
                                  children: [
                                    Span(
                                      className:
                                          'text-slate-500 dark:text-slate-400 font-bold shrink-0',
                                      text: r'$',
                                    ),
                                    Span(
                                      className:
                                          'text-slate-800 dark:text-slate-200 font-semibold '
                                          'truncate',
                                      text:
                                          'dart pub global activate bloom_cli',
                                    ),
                                  ],
                                ),
                                Button(
                                  attrs: const {'type': 'button'},
                                  className:
                                      'px-3 sm:px-4 py-2 bg-white dark:bg-zinc-900 '
                                      'group-hover:bg-slate-900 group-hover:text-white '
                                      'rounded-xl text-xs font-mono font-bold text-slate-700 '
                                      'dark:text-slate-200 dark:group-hover:text-white '
                                      'transition-colors flex items-center gap-1.5 shrink-0 '
                                      'border border-slate-200 dark:border-zinc-800 shadow-sm',
                                  children: [
                                    hugeIcon(
                                      'terminal',
                                      className: 'w-3.5 h-3.5 sm:w-4 sm:h-4',
                                    ),
                                    Span(
                                      className: 'hidden sm:inline',
                                      text: 'Copy',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Quick Links
                        Div(
                          className:
                              'flex flex-wrap items-center justify-center gap-3 pt-2',
                          children: [
                            A(
                              href: '/bloom',
                              className:
                                  'px-4 py-2 rounded-xl bg-purple-600 hover:bg-purple-500 '
                                  'text-white font-bold text-xs shadow-md transition flex '
                                  'items-center gap-1.5',
                              children: [
                                hugeIcon('sparkles', className: 'w-3.5 h-3.5'),
                                const Text('Components (60+)'),
                              ],
                            ),
                            A(
                              href: '/build',
                              className:
                                  'px-4 py-2 rounded-xl bg-slate-100 dark:bg-zinc-950 '
                                  'hover:bg-slate-200 dark:hover:bg-zinc-800 text-slate-900 '
                                  'dark:text-white font-bold text-xs border '
                                  'border-slate-200 dark:border-zinc-800 shadow-sm '
                                  'transition flex items-center gap-1.5',
                              children: [const Text('Documentation')],
                            ),
                            A(
                              href: '/blocks',
                              className:
                                  'px-4 py-2 rounded-xl bg-slate-100 dark:bg-zinc-950 '
                                  'hover:bg-slate-200 dark:hover:bg-zinc-800 text-slate-900 '
                                  'dark:text-white font-bold text-xs border '
                                  'border-slate-200 dark:border-zinc-800 shadow-sm '
                                  'transition flex items-center gap-1.5',
                              children: [const Text('Blocks')],
                            ),
                            A(
                              href: '/bloom',
                              className:
                                  'px-4 py-2 rounded-xl bg-slate-100 dark:bg-zinc-950 '
                                  'hover:bg-slate-200 dark:hover:bg-zinc-800 text-slate-900 '
                                  'dark:text-white font-bold text-xs border '
                                  'border-slate-200 dark:border-zinc-800 shadow-sm '
                                  'transition flex items-center gap-1.5',
                              children: [const Text('Theme Studio')],
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Tech Marquee
          techMarquee(),

          // 3. Platform Metrics Band
          Section(
            className: 'py-14 lg:py-16 max-w-6xl mx-auto px-4',
            children: [
              Div(
                className: 'grid grid-cols-2 md:grid-cols-4 gap-8 md:gap-0 '
                    'divide-y-0 md:divide-x divide-slate-200 '
                    'dark:divide-slate-800 max-w-6xl mx-auto',
                children: [
                  Div(
                    className: 'text-center space-y-1.5 px-4',
                    children: [
                      Div(
                        className:
                            'text-4xl sm:text-5xl font-black tracking-tight '
                            'text-slate-900 dark:text-white',
                        text: '142',
                      ),
                      Div(
                        className:
                            'text-[11px] font-mono uppercase tracking-widest '
                            'text-slate-500 dark:text-slate-400',
                        text: 'Edge CDN nodes',
                      ),
                    ],
                  ),
                  Div(
                    className: 'text-center space-y-1.5 px-4',
                    children: [
                      Div(
                        className:
                            'text-4xl sm:text-5xl font-black tracking-tight '
                            'text-slate-900 dark:text-white',
                        text: '1.2s',
                      ),
                      Div(
                        className:
                            'text-[11px] font-mono uppercase tracking-widest '
                            'text-slate-500 dark:text-slate-400',
                        text: 'OTA patch broadcast',
                      ),
                    ],
                  ),
                  Div(
                    className: 'text-center space-y-1.5 px-4',
                    children: [
                      Div(
                        className:
                            'text-4xl sm:text-5xl font-black tracking-tight '
                            'text-slate-900 dark:text-white',
                        text: '150KB',
                      ),
                      Div(
                        className:
                            'text-[11px] font-mono uppercase tracking-widest '
                            'text-slate-500 dark:text-slate-400',
                        text: 'Avg delta patch',
                      ),
                    ],
                  ),
                  Div(
                    className: 'text-center space-y-1.5 px-4',
                    children: [
                      Div(
                        className:
                            'text-4xl sm:text-5xl font-black tracking-tight '
                            'text-slate-900 dark:text-white',
                        text: '60fps',
                      ),
                      Div(
                        className:
                            'text-[11px] font-mono uppercase tracking-widest '
                            'text-slate-500 dark:text-slate-400',
                        text: 'Impeller rendering',
                      ),
                    ],
                  ),
                ],
              ),
              P(
                className: 'text-center text-[11px] font-mono uppercase '
                    'tracking-widest text-slate-400 dark:text-slate-500 mt-10',
                text: 'RSA-2048 Signed Patches  ·  Deterministic Builds  ·  '
                    'Typed Route Safety',
              ),
            ],
          ),

          // 4. Ecosystem Orchestration Section
          Section(
            attrs: const {'id': 'orchestration'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [
              Div(
                className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
                children: [
                  Div(
                    className:
                        'inline-flex items-center gap-1.5 px-3 py-1 rounded-full '
                        'glass-panel text-xs font-mono font-bold text-slate-600 '
                        'dark:text-slate-300',
                    children: [
                      hugeIcon(
                        'sparkles',
                        className:
                            'w-3.5 h-3.5 text-slate-500 dark:text-slate-400',
                      ),
                      Span(text: 'Executive Strategy'),
                    ],
                  ),
                  H2(
                    className: 'text-4xl sm:text-5xl font-black tracking-tight '
                        'text-slate-900 dark:text-white',
                    children: [
                      const Text('Make the good parts of Dart & Flutter'),
                      El('br'),
                      Span(
                        className: 'text-gradient-silver',
                        text: 'feel like one cohesive framework.',
                      ),
                    ],
                  ),
                  P(
                    className: 'text-slate-600 dark:text-slate-400 text-lg '
                        'leading-relaxed',
                    text:
                        'Bloom delegates mature low-level infrastructure (Flutter '
                        'rendering, go_router, signals, Shorebird OTA) while '
                        'owning the end-to-end developer experience.',
                  ),
                ],
              ),

              // 4a. 5-Step Orchestration Pipeline
              orchestrationPipeline(),

              // 4b. Chapter Cards (BUILD • SHIP • BLOOM)
              Div(className: 'mt-20', children: [chapterCards()]),
            ],
          ),

          // 5. Feature Showcase Grid
          Section(
            attrs: const {'id': 'feature-showcase'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [
              Div(
                className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
                children: [
                  H2(
                    className: 'text-3xl sm:text-4xl font-black tracking-tight '
                        'text-slate-900 dark:text-white',
                    text: 'Everything you need to ship Flutter apps',
                  ),
                  P(
                    className:
                        'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                    text:
                        'One cohesive platform across architecture, delivery, and '
                        'UI — no glue code required.',
                  ),
                ],
              ),
              featureGridShowcase(),
            ],
          ),

          // 6. CLI Command Matrix Section
          Section(
            attrs: const {'id': 'cli-matrix'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [
              Div(
                className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
                children: [
                  H2(
                    className: 'text-3xl sm:text-4xl font-black text-slate-900 '
                        'dark:text-white',
                    text: 'Bloom CLI Tooling Matrix',
                  ),
                  P(
                    className:
                        'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                    text: 'One unified CLI orchestrating Dart, Flutter, build '
                        'generators, and deployment channels.',
                  ),
                ],
              ),
              cliToolingExplorer(),
            ],
          ),

          // 7. Performance & Dart Advantage (SEO & Benchmarks)
          Section(
            attrs: const {'id': 'performance-truth'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [
              Div(
                className: 'text-center max-w-3xl mx-auto space-y-4 mb-12',
                children: [
                  Div(
                    className:
                        'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                        'bg-emerald-500/10 border border-emerald-500/20 '
                        'text-emerald-600 dark:text-emerald-400 text-xs font-mono '
                        'font-bold',
                    children: [
                      hugeIcon('zap', className: 'w-3.5 h-3.5'),
                      Span(
                        text:
                            'Verified Hardware Benchmarks (8 vCPUs, Linux x64)',
                      ),
                    ],
                  ),
                  H2(
                    className: 'text-3xl sm:text-5xl font-black tracking-tight '
                        'text-slate-900 dark:text-white',
                    text: 'Why Pure Dart & Bloom Destroy JavaScript at Scale',
                  ),
                  P(
                    className:
                        'text-slate-600 dark:text-slate-400 text-base sm:text-lg '
                        'leading-relaxed',
                    children: [
                      const Text(
                        'For years, developers underestimated Dart as a client-only language. In real-world multi-core benchmarks, Bloom’s zero-cost AOT abstractions, native isolates, and pure Dart ORM consistently outpace the dominant Node.js, Fastify, and NestJS ecosystems while consuming ',
                      ),
                      El('strong', text: '30x less memory'),
                      const Text('.'),
                    ],
                  ),
                ],
              ),

              // 4-Pillar Performance Grid
              Div(
                className:
                    'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 '
                    'max-w-6xl mx-auto',
                children: [
                  // Card 1: WebSockets
                  Div(
                    className:
                        'p-6 rounded-3xl glass-panel border border-slate-200 '
                        'dark:border-zinc-800 space-y-4 relative overflow-hidden '
                        'group hover:border-pink-500/40 transition '
                        'mouse-glow-card',
                    children: [
                      Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Span(
                            className:
                                'text-xs font-mono font-bold text-pink-500 uppercase '
                                'tracking-wider',
                            text: 'Realtime WebSockets',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                                'bg-pink-500/10 text-pink-400 border border-pink-500/20',
                            text: '78k msgs/s',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'text-2xl font-black text-slate-900 dark:text-white '
                            'tracking-tight',
                        text: '2x Faster Than Fastify',
                      ),
                      P(
                        className: 'text-xs text-slate-600 dark:text-slate-400 '
                            'leading-relaxed',
                        children: [
                          const Text('50,000 fan-out messages delivered in '),
                          El('strong', text: '640 ms'),
                          const Text(' across 1,000 active sockets at '),
                          El('strong', text: '3.70 MB RAM'),
                          const Text(
                            '. Fastify & NestJS took 1,260 ms at 115 MB RAM.',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'pt-2 border-t border-slate-200 dark:border-zinc-800/80 '
                            'flex items-center justify-between text-[11px] font-mono',
                        children: [
                          Span(
                            className: 'text-slate-500',
                            text: 'Memory with 1k Sockets:',
                          ),
                          Span(
                            className: 'font-bold text-emerald-500',
                            text: '3.7 MB vs 114 MB',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Card 2: SQLite Native ORM
                  Div(
                    className:
                        'p-6 rounded-3xl glass-panel border border-slate-200 '
                        'dark:border-zinc-800 space-y-4 relative overflow-hidden '
                        'group hover:border-purple-500/40 transition '
                        'mouse-glow-card',
                    children: [
                      Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Span(
                            className:
                                'text-xs font-mono font-bold text-purple-500 uppercase '
                                'tracking-wider',
                            text: 'SQLite Native ORM',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                                'bg-purple-500/10 text-purple-400 border '
                                'border-purple-500/20',
                            text: '12.5k ops/s',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'text-2xl font-black text-slate-900 dark:text-white '
                            'tracking-tight',
                        text: '12.7x Faster Than Prisma',
                      ),
                      P(
                        className: 'text-xs text-slate-600 dark:text-slate-400 '
                            'leading-relaxed',
                        children: [
                          const Text('5,000 point lookups completed in '),
                          El('strong', text: '400 ms'),
                          const Text(
                            '. Prisma took 5,089 ms and Drizzle took 731 ms. Bulk 2,300+ row update finished in ',
                          ),
                          El('strong', text: '2 ms'),
                          const Text('.'),
                        ],
                      ),
                      Div(
                        className:
                            'pt-2 border-t border-slate-200 dark:border-zinc-800/80 '
                            'flex items-center justify-between text-[11px] font-mono',
                        children: [
                          Span(
                            className: 'text-slate-500',
                            text: '5k Point Lookups:',
                          ),
                          Span(
                            className: 'font-bold text-emerald-500',
                            text: '400ms vs 5,089ms',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Card 3: HTTP Concurrency
                  Div(
                    className:
                        'p-6 rounded-3xl glass-panel border border-slate-200 '
                        'dark:border-zinc-800 space-y-4 relative overflow-hidden '
                        'group hover:border-blue-500/40 transition '
                        'mouse-glow-card',
                    children: [
                      Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Span(
                            className:
                                'text-xs font-mono font-bold text-blue-500 uppercase '
                                'tracking-wider',
                            text: 'HTTP Concurrency',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                                'bg-blue-500/10 text-blue-400 border border-blue-500/20',
                            text: '9.1k req/s',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'text-2xl font-black text-slate-900 dark:text-white '
                            'tracking-tight',
                        text: '3.6x Throughput of NestJS',
                      ),
                      P(
                        className: 'text-xs text-slate-600 dark:text-slate-400 '
                            'leading-relaxed',
                        children: [
                          const Text(
                            'Under 1,000 concurrent HTTP keep-alive connections, Bloom maintained ',
                          ),
                          El('strong', text: '29.3 ms p99 latency'),
                          const Text(
                            ' with zero spikes. NestJS spiked to 1,120 ms p99.',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'pt-2 border-t border-slate-200 dark:border-zinc-800/80 '
                            'flex items-center justify-between text-[11px] font-mono',
                        children: [
                          Span(
                            className: 'text-slate-500',
                            text: 'p99 Latency under 1k Conn:',
                          ),
                          Span(
                            className: 'font-bold text-emerald-500',
                            text: '29ms vs 1,120ms',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Card 4: Frontend Query SWR
                  Div(
                    className:
                        'p-6 rounded-3xl glass-panel border border-slate-200 '
                        'dark:border-zinc-800 space-y-4 relative overflow-hidden '
                        'group hover:border-emerald-500/40 transition '
                        'mouse-glow-card',
                    children: [
                      Div(
                        className: 'flex items-center justify-between',
                        children: [
                          Span(
                            className:
                                'text-xs font-mono font-bold text-emerald-500 uppercase '
                                'tracking-wider',
                            text: 'Frontend Query SWR',
                          ),
                          Span(
                            className:
                                'px-2 py-0.5 rounded text-[10px] font-mono font-bold '
                                'bg-emerald-500/10 text-emerald-400 border '
                                'border-emerald-500/20',
                            text: '119k ops/s',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'text-2xl font-black text-slate-900 dark:text-white '
                            'tracking-tight',
                        text: '1.5x TanStack Query',
                      ),
                      P(
                        className: 'text-xs text-slate-600 dark:text-slate-400 '
                            'leading-relaxed',
                        children: [
                          const Text('10,000 bulk cache writes resolved in '),
                          El('strong', text: '84 ms'),
                          const Text(
                            ' with zero full widget rebuilds via fine-grained reactive Signals. TanStack Query took 132 ms.',
                          ),
                        ],
                      ),
                      Div(
                        className:
                            'pt-2 border-t border-slate-200 dark:border-zinc-800/80 '
                            'flex items-center justify-between text-[11px] font-mono',
                        children: [
                          Span(
                            className: 'text-slate-500',
                            text: '1k Request Deduplication:',
                          ),
                          Span(
                            className: 'font-bold text-emerald-500',
                            text: '23ms vs 34ms',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // 8. Community & Testimonials
          Section(
            attrs: const {'id': 'community'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [
              Div(
                className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
                children: [
                  H2(
                    className: 'text-3xl sm:text-4xl font-black tracking-tight '
                        'text-slate-900 dark:text-white',
                    text: 'Loved by Flutter developers',
                  ),
                  P(
                    className:
                        'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                    text:
                        'Built by Flutter developers, for Flutter developers. '
                        'Join the conversation.',
                  ),
                ],
              ),
              communityShowcase(),
            ],
          ),

          // 9. Frequently Asked Questions
          Section(
            attrs: const {'id': 'faq'},
            className: 'py-24 px-6 max-w-7xl mx-auto w-full border-t '
                'border-zinc-800/80 scroll-reveal',
            children: [hubFaq()],
          ),
        ],
      ),
    ),
    onMount: () {
      typedText.value = '';
      isTyping.value = true;
      isFinished.value = false;
      schedule(const Duration(milliseconds: 200), typeNext);
    },
    onUnmount: () => typingTimer?.cancel(),
  );
}
