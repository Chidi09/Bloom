import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class Testimonial {
  final String id;
  final String quote;
  final String author;
  final String handle;
  final String role;
  final String company;
  final String avatar;
  final String category;
  final int stars;
  final String highlightText;

  const Testimonial({
    required this.id,
    required this.quote,
    required this.author,
    required this.handle,
    required this.role,
    required this.company,
    required this.avatar,
    required this.category,
    required this.stars,
    required this.highlightText,
  });
}

final communityFilter = signal('all');
final communityStarred = signal(false);
final communityStarCount = signal(18420);

BloomNode communityShowcase() {
  const testimonials = [
    Testimonial(
      id: '1',
      quote:
          'Bloom replaced our fragmented state packages and custom '
          'router with pure file-system routing and signals. Our release '
          'velocity doubled in the first sprint.',
      author: 'Alex Rivers',
      handle: '@arivers_dev',
      role: 'Mobile Tech Lead',
      company: 'Vercel Mobile',
      avatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'leads',
      stars: 5,
      highlightText: 'Release velocity doubled in 1 sprint',
    ),
    Testimonial(
      id: '2',
      quote:
          'Shorebird-powered OTA through Bloom Cloud is magic. We '
          'patched a critical payment flow bug on 400,000 active iOS '
          '& Android devices in 1.4 seconds.',
      author: 'Elena Rostova',
      handle: '@erostova_flutter',
      role: 'Principal Engineer',
      company: 'Fintech Labs',
      avatar:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'architects',
      stars: 5,
      highlightText: 'Patched 400k devices in 1.4s',
    ),
    Testimonial(
      id: '3',
      quote:
          'The DI boot sequence and typed route generation in Bloom '
          'feel like Next.js for mobile. Finally a framework that '
          'respects Dart’s sound null safety.',
      author: 'Marcus Vance',
      handle: '@marcusvance',
      role: 'Core Contributor',
      company: 'Flutter Ecosystem',
      avatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'contributors',
      stars: 5,
      highlightText: 'Next.js DX for Flutter',
    ),
    Testimonial(
      id: '4',
      quote:
          'Bloom UI Studio’s shadcn primitives bring '
          'production-grade mobile tokens to Flutter. Customizing '
          'border-radius and color swatches live at 60fps is '
          'unreal.',
      author: 'Sofia Chen',
      handle: '@sofiachen_ui',
      role: 'Design Systems Lead',
      company: 'Bloom Studio',
      avatar:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'leads',
      stars: 5,
      highlightText: 'Production-grade mobile tokens',
    ),
    Testimonial(
      id: '5',
      quote:
          'We migrated 6 production Flutter apps to Bloom in under '
          'two weeks. Zero boilerplate, instant hot reload state '
          'preservation, and crisp developer DX.',
      author: "David O'Connor",
      handle: '@doconnor_app',
      role: 'Founder & Architect',
      company: 'MobileStack',
      avatar:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'architects',
      stars: 5,
      highlightText: '6 production apps migrated',
    ),
    Testimonial(
      id: '6',
      quote:
          'Bloom Query eliminated 90% of our manual API state code. '
          'Automatic caching, optimistic mutations, and signals '
          'reactivity work seamlessly out of the box.',
      author: 'Kaito Tanaka',
      handle: '@kaito_dart',
      role: 'Staff Software Engineer',
      company: 'Global Cloud',
      avatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
      category: 'contributors',
      stars: 5,
      highlightText: 'Eliminated 90% manual state code',
    ),
  ];

  return Div(
    className: 'max-w-6xl mx-auto space-y-12',
    children: [
      // Filter Tabs
      Div(
        className: 'flex flex-wrap items-center justify-center gap-2',
        children: [
          for (final (cat, label) in [
            ('all', 'All Testimonials (6)'),
            ('leads', 'Tech Leads'),
            ('architects', 'Mobile Architects'),
            ('contributors', 'Core Contributors'),
          ])
            Live(() {
              final isActive = communityFilter.value == cat;
              return Button(
                onClick: (_) => communityFilter.value = cat,
                className:
                    'px-4 py-2 rounded-xl text-xs font-semibold tracking-tight transition-all border ${isActive ? 'bg-white text-slate-950 border-white shadow-md font-black' : 'bg-black text-slate-400 hover:text-white border-zinc-800'}',
                text: label,
              );
            }),
        ],
      ),

      // Testimonial Cards Grid
      Live(() {
        final f = communityFilter.value;
        final list = f == 'all'
            ? testimonials
            : testimonials.where((t) => t.category == f).toList();

        return Div(
          className: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6',
          children: [
            for (final t in list)
              Div(
                className:
                    'group relative p-6 rounded-2xl bg-slate-950/90 '
                    'dark:bg-black/95 backdrop-blur border border-slate-800 '
                    'dark:border-white/10 hover:border-slate-700 '
                    'dark:hover:border-white/20 hover:shadow-xl '
                    'transition-all duration-300 flex flex-col '
                    'justify-between',
                children: [
                  Div(
                    children: [
                      // Highlight Tag & Star Rating
                      Div(
                        className:
                            'flex items-center justify-between mb-4 pb-3 border-b '
                            'border-slate-800 dark:border-zinc-800',
                        children: [
                          Span(
                            className:
                                'inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md '
                                'bg-zinc-900 text-slate-200 text-[10px] font-mono '
                                'font-bold border border-zinc-800',
                            children: [
                              hugeIcon(
                                'sparkles',
                                className: 'w-3 h-3 text-purple-400',
                              ),
                              Span(text: t.highlightText),
                            ],
                          ),
                          Div(
                            className:
                                'flex items-center gap-0.5 text-amber-400',
                            children: [
                              for (var i = 0; i < t.stars; i++)
                                hugeIcon(
                                  'star',
                                  className:
                                      'w-3.5 h-3.5 fill-amber-400 text-amber-400',
                                ),
                            ],
                          ),
                        ],
                      ),
                      P(
                        className:
                            'text-xs sm:text-sm text-slate-300 leading-relaxed mb-6 '
                            'font-normal italic',
                        text: '"${t.quote}"',
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'flex items-center gap-3.5 pt-4 border-t border-slate-800 '
                        'dark:border-zinc-800',
                    children: [
                      Img(
                        src: t.avatar,
                        alt: t.author,
                        className:
                            'w-10 h-10 rounded-full object-cover border '
                            'border-zinc-700 flex-shrink-0 group-hover:scale-105 '
                            'transition-transform',
                        attrs: const {'loading': 'lazy', 'decoding': 'async'},
                      ),
                      Div(
                        className: 'min-w-0 flex-1',
                        children: [
                          Div(
                            className: 'flex items-center gap-1.5',
                            children: [
                              Span(
                                className:
                                    'text-xs font-bold text-white truncate',
                                text: t.author,
                              ),
                              hugeIcon(
                                'check-circle',
                                className:
                                    'w-3.5 h-3.5 text-teal-400 flex-shrink-0',
                              ),
                            ],
                          ),
                          Div(
                            className:
                                'text-[11px] font-mono text-slate-400 truncate',
                            children: [
                              Span(text: '${t.role} · '),
                              Span(
                                className: 'text-slate-200 font-semibold',
                                text: t.company,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      }),

      // Dynamic Community Ecosystem Banner
      Div(
        className:
            'p-8 sm:p-10 rounded-3xl bg-black text-white border '
            'border-zinc-800 relative overflow-hidden shadow-2xl',
        children: [
          Div(
            className:
                'absolute top-0 right-0 w-96 h-96 bg-purple-500/5 '
                'rounded-full blur-3xl pointer-events-none',
          ),
          Div(
            className:
                'grid grid-cols-1 lg:grid-cols-12 gap-8 items-center '
                'relative z-10',
            children: [
              // Left Stacked Avatars & Contributor Stats
              Div(
                className: 'lg:col-span-7 space-y-4',
                children: [
                  Div(
                    className: 'flex items-center gap-2',
                    children: [
                      Div(
                        className: 'flex -space-x-3 overflow-hidden',
                        children: [
                          for (final t in testimonials)
                            Img(
                              src: t.avatar,
                              alt: t.author,
                              className:
                                  'inline-block h-9 w-9 rounded-full ring-2 ring-black '
                                  'object-cover',
                              attrs: const {'loading': 'lazy'},
                            ),
                        ],
                      ),
                      Span(
                        className:
                            'text-xs font-mono font-bold text-slate-400 pl-2',
                        text: '+5,000 Contributors',
                      ),
                    ],
                  ),
                  H3(
                    className:
                        'text-2xl sm:text-3xl font-black tracking-tight '
                        'text-white',
                    text: '5,000+ contributors. Open to everyone.',
                  ),
                  P(
                    className:
                        'text-xs sm:text-sm text-slate-300 leading-relaxed '
                        'font-normal',
                    text:
                        'Bloom is built in the open by Flutter core contributors, '
                        'mobile architects, and developers worldwide. Join our '
                        'Discord or star us on GitHub to shape the future of '
                        'Flutter.',
                  ),
                ],
              ),

              // Right Interactive CTA Buttons
              Div(
                className:
                    'lg:col-span-5 flex flex-col sm:flex-row lg:flex-col gap-3',
                children: [
                  Live(() {
                    final starred = communityStarred.value;
                    final count = communityStarCount.value;
                    return Button(
                      onClick: (_) {
                        if (starred) {
                          communityStarred.value = false;
                          communityStarCount.value--;
                        } else {
                          communityStarred.value = true;
                          communityStarCount.value++;
                        }
                      },
                      className:
                          'w-full px-5 py-3 rounded-xl font-bold text-xs flex items-center justify-between transition-all ${starred ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-400/20' : 'bg-white text-slate-950 hover:bg-slate-200 shadow-md font-black'}',
                      children: [
                        Div(
                          className: 'flex items-center gap-2',
                          children: [
                            hugeIcon(
                              'star',
                              className:
                                  'w-4 h-4 ${starred ? 'fill-slate-950 text-slate-950' : 'fill-slate-950 text-slate-950'}',
                            ),
                            Span(
                              text: starred
                                  ? 'Starred on GitHub!'
                                  : 'Star Bloom on GitHub',
                            ),
                          ],
                        ),
                        Span(
                          className: 'font-mono text-[11px] opacity-80',
                          text: '$count ★',
                        ),
                      ],
                    );
                  }),
                  A(
                    href: 'https://discord.gg',
                    attrs: const {'target': '_blank', 'rel': 'noreferrer'},
                    className:
                        'w-full px-5 py-3 rounded-xl bg-zinc-900 '
                        'hover:bg-zinc-800 text-white font-bold text-xs flex '
                        'items-center justify-between border border-zinc-800 '
                        'transition-all',
                    children: [
                      Div(
                        className: 'flex items-center gap-2',
                        children: [
                          hugeIcon(
                            'message-square',
                            className: 'w-4 h-4 text-purple-400',
                          ),
                          Span(text: 'Join the Discord Community'),
                        ],
                      ),
                      hugeIcon(
                        'arrow-up-right',
                        className: 'w-4 h-4 text-slate-400',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
