/// Hero viewport section with looping ambient background video, dynamic typing effect, and key CTAs.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;
import '../config.dart';
import '../plugins/lenis_scroll.dart';
import '../plugins/lucide_icons.dart';
import '../plugins/typed_text.dart';

/// Full-viewport hero component introducing the developer.
class HeroSectionComponent {
  final Ref<Object> _typedRef = Ref<Object>();
  TypedEffect? _typedEffect;

  BloomNode build() {
    return Mount(
      Section(
        attrs: {
          'id': 'hero',
          ...aria(
            role: AriaRole.region,
            label: 'Introduction & Hero Overview',
          ),
        },
        className:
            'relative min-h-screen flex items-center justify-center overflow-hidden pt-16 pb-12 px-4 sm:px-6 lg:px-8',
        children: [
          // Ambient Background Video Layer (Decorative only, muted, auto-looping)
          Div(
            className: 'absolute inset-0 z-0 overflow-hidden pointer-events-none select-none',
            attrs: aria(hidden: true),
            children: [
              El(
                'video',
                attrs: {
                  'autoplay': '',
                  'muted': '',
                  'loop': '',
                  'playsinline': '',
                  'poster': PortfolioPersona.heroPosterUrl,
                  'aria-hidden': 'true',
                },
                className: 'w-full h-full object-cover opacity-20 filter blur-[0.5px]',
                children: [
                  El(
                    'source',
                    attrs: {
                      'src': PortfolioPersona.heroVideoUrl,
                      'type': 'video/mp4',
                    },
                  ),
                ],
              ),
              // Dark Gradient Scrim overlay to guarantee strict text legibility
              Div(
                className:
                    'absolute inset-0 bg-gradient-to-b from-zinc-950/80 via-zinc-950/90 to-zinc-950',
              ),
            ],
          ),

          // Central Hero Content
          Div(
            className: 'relative z-10 max-w-4xl mx-auto text-center flex flex-col items-center',
            children: [
              // Availability Pill Badge
              Div(
                className:
                    'inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-950/60 border border-indigo-500/30 text-indigo-300 text-xs font-mono font-medium mb-8 shadow-sm backdrop-blur-sm',
                children: [
                  Span(
                    className:
                        'w-2 h-2 rounded-full bg-emerald-400 animate-pulse',
                  ),
                  const Text('Available for Q3/Q4 engineering leadership & contracts'),
                ],
              ),

              // Headline Name
              H1(
                className:
                    // text-zinc-50, not text-white: the zinc scale is inverted
                    // for the light theme (see web/index.html), so this reads
                    // near-white on dark and near-black on light. A literal
                    // text-white would stay white and vanish in light mode.
                    'text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-zinc-50 mb-4',
                children: [
                  const Text('Hi, I am '),
                  Span(
                    className:
                        'bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 via-sky-300 to-indigo-200',
                    text: PortfolioPersona.name,
                  ),
                ],
              ),

              // Animated Typing Role Headline
              H2(
                className:
                    'text-xl sm:text-2xl md:text-3xl font-mono font-medium text-zinc-300 min-h-[2.5rem] mb-6 flex items-center justify-center gap-1',
                children: [
                  RefNode(
                    _typedRef,
                    Span(
                      className: 'text-indigo-400 font-semibold',
                      text: PortfolioPersona.typedRoles.first,
                    ),
                  ),
                ],
              ),

              // Value Proposition
              P(
                className:
                    'text-base sm:text-lg md:text-xl text-zinc-400 max-w-2xl mx-auto leading-relaxed mb-10 font-normal',
                text: PortfolioPersona.tagline,
              ),

              // Action Buttons
              Div(
                className: 'flex flex-col sm:flex-row items-center gap-4 w-full sm:w-auto mb-16',
                children: [
                  // Primary CTA: View Projects
                  Button(
                    attrs: {
                      'type': 'button',
                      ...aria(
                        label: 'Explore featured engineering projects',
                      ),
                    },
                    className:
                        'w-full sm:w-auto inline-flex items-center justify-center gap-2 px-7 py-3.5 rounded-xl font-medium text-sm text-white bg-indigo-600 hover:bg-indigo-500 shadow-lg shadow-indigo-600/25 hover:shadow-indigo-600/40 hover:-translate-y-0.5 transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                    onClick: (_) => LenisScroll.scrollTo('#projects'),
                    children: [
                      Span(text: 'View Work'),
                      Raw(LucideIcons.svg(LucideIconName.arrowUpRight, className: 'w-4 h-4')),
                    ],
                  ),

                  // Secondary CTA: Contact Form
                  Button(
                    attrs: {
                      'type': 'button',
                      ...aria(
                        label: 'Scroll to contact and inquiry form',
                      ),
                    },
                    className:
                        'w-full sm:w-auto inline-flex items-center justify-center gap-2 px-7 py-3.5 rounded-xl font-medium text-sm text-zinc-200 bg-zinc-900/90 hover:bg-zinc-800 border border-zinc-800 hover:border-zinc-700 hover:-translate-y-0.5 transition-all focus:outline-none focus-visible:ring-2 focus-visible:ring-zinc-500',
                    onClick: (_) => LenisScroll.scrollTo('#contact'),
                    children: [
                      Raw(LucideIcons.svg(LucideIconName.mail, className: 'w-4 h-4 text-zinc-400')),
                      Span(text: 'Get in Touch'),
                    ],
                  ),
                ],
              ),

              // Core Technology Stack Highlights
              Div(
                className:
                    'pt-8 border-t border-zinc-900/80 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-xs font-mono text-zinc-500',
                children: [
                  Span(
                    className: 'uppercase tracking-widest text-zinc-600 font-semibold',
                    text: 'Core Competencies:',
                  ),
                  _techPill('Rust & Raft'),
                  _techPill('Dart & WASM'),
                  _techPill('Bloom AST'),
                  _techPill('eBPF / Go'),
                  _techPill('Distributed LSM'),
                ],
              ),
            ],
          ),
        ],
      ),
      onMount: () {
        if (_typedRef.isMounted) {
          _typedEffect = TypedEffect.start(
            _typedRef.value as web.Element,
            strings: PortfolioPersona.typedRoles,
          );
        }
      },
      onUnmount: () {
        _typedEffect?.destroy();
        _typedEffect = null;
      },
    );
  }

  BloomNode _techPill(String label) {
    return Span(
      className:
          'px-2.5 py-1 rounded bg-zinc-900/90 border border-zinc-800/80 text-zinc-300',
      text: label,
    );
  }
}
