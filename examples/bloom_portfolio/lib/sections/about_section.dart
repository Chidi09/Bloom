/// About section highlighting developer background, technical philosophy, and core skills.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import '../config.dart';
import '../plugins/lucide_icons.dart';

/// About section component.
class AboutSectionComponent {
  BloomNode build() {
    return Section(
      attrs: {
        'id': 'about',
        ...aria(
          role: AriaRole.region,
          label: 'About Alex Rivera — Biography and Technical Skills',
        ),
      },
      className: 'py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-zinc-900',
      children: [
        // Section Header
        Div(
          className: 'mb-16',
          children: [
            Span(
              className: 'font-mono text-xs text-indigo-400 font-semibold tracking-widest uppercase mb-2 block',
              text: '01. Background & Philosophy',
            ),
            H2(
              className: 'text-3xl sm:text-4xl font-bold tracking-tight text-zinc-50',
              text: 'Architecting for Resilience & Speed',
            ),
          ],
        ),

        // Grid: Bio & Portrait + Skills Grid
        Div(
          className: 'grid grid-cols-1 lg:grid-cols-12 gap-12 items-start',
          children: [
            // Left Column: Portrait and Personal Bio (5 cols)
            Div(
              className: 'lg:col-span-5 flex flex-col gap-6',
              children: [
                // Portrait Image using framework's responsive image API
                Div(
                  className: 'relative group rounded-2xl overflow-hidden border border-zinc-800 bg-zinc-900 shadow-2xl',
                  children: [
                    bloomImage(
                      src: PortfolioPersona.portraitUrl,
                      alt: 'Portrait photograph of Alex Rivera, Senior Systems Engineer',
                      width: 600,
                      height: 720,
                      aspectRatio: '5/6',
                      fit: ImageFit.cover,
                      className:
                          'w-full h-auto object-cover grayscale contrast-125 group-hover:grayscale-0 transition-all duration-500',
                      placeholder: '#18181b',
                    ),
                    // Ambient Gradient Corner Accents
                    Div(
                      className:
                          'absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-transparent opacity-60 pointer-events-none',
                    ),
                    Div(
                      className:
                          'absolute bottom-4 left-4 right-4 p-4 rounded-xl backdrop-blur-md bg-zinc-950/80 border border-zinc-800/80 flex items-center justify-between text-xs font-mono',
                      children: [
                        Div(
                          children: [
                            Span(className: 'text-zinc-400 block', text: 'Location'),
                            Span(className: 'text-zinc-200 font-medium', text: PortfolioPersona.location),
                          ],
                        ),
                        Div(
                          className: 'text-right',
                          children: [
                            Span(className: 'text-zinc-400 block', text: 'Experience'),
                            Span(className: 'text-indigo-400 font-medium', text: '8+ Years'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Narrative Bio
                P(
                  className: 'text-zinc-300 leading-relaxed text-sm sm:text-base font-normal',
                  text: PortfolioPersona.shortBio,
                ),
                P(
                  className: 'text-zinc-400 leading-relaxed text-sm',
                  text:
                      'My engineering philosophy centers on mechanical sympathy: understanding kernel syscalls, memory cache hierarchies, and zero-allocation pipelines to produce systems that remain deterministic under high load.',
                ),
              ],
            ),

            // Right Column: Technical Core Competencies (7 cols)
            Div(
              className: 'lg:col-span-7 flex flex-col gap-6',
              children: [
                _skillCard(
                  icon: LucideIconName.server,
                  title: 'Distributed Systems & Cloud Architecture',
                  description:
                      'Designing fault-tolerant consensus systems, Raft clusters, LSM storage engines, and edge reverse proxies with eBPF and gRPC.',
                  badges: ['Raft', 'Rust', 'gRPC', 'eBPF', 'Kubernetes', 'Redis', 'PostgreSQL'],
                ),
                _skillCard(
                  icon: LucideIconName.layers,
                  title: 'Reactive Frontend & Framework Engineering',
                  description:
                      'Pioneering fine-grained reactivity using Bloom Signals, declarative pure-Dart AST compilation, sub-millisecond SSR, and zero-virtual-DOM rendering.',
                  badges: ['Bloom JS Native', 'Dart', 'Signals', 'WASM', 'WebSockets', 'Tailwind'],
                ),
                _skillCard(
                  icon: LucideIconName.terminal,
                  title: 'Low-Level Performance & Tooling',
                  description:
                      'SIMD vectorization (AVX-512), zero-copy serialization, compiler toolchain optimization, and deterministic benchmarking pipelines.',
                  badges: ['SIMD AVX', 'C++', 'Memory Profiling', 'Flamegraphs', 'GitHub Actions'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _skillCard({
    required LucideIconName icon,
    required String title,
    required String description,
    required List<String> badges,
  }) {
    return Div(
      className:
          'p-6 rounded-2xl bg-zinc-900/50 border border-zinc-800/80 hover:border-zinc-700 transition-colors shadow-sm',
      children: [
        Div(
          className: 'flex items-center gap-3.5 mb-3',
          children: [
            Div(
              className:
                  'w-10 h-10 rounded-xl bg-indigo-600/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400',
              children: [
                Raw(LucideIcons.svg(icon, className: 'w-5 h-5')),
              ],
            ),
            H3(
              className: 'text-base sm:text-lg font-semibold text-zinc-100',
              text: title,
            ),
          ],
        ),
        P(
          className: 'text-zinc-400 text-sm leading-relaxed mb-4',
          text: description,
        ),
        Div(
          className: 'flex flex-wrap gap-2',
          children: badges
              .map(
                (badge) => Span(
                  className:
                      'px-2.5 py-1 rounded-md bg-zinc-800/60 border border-zinc-700/60 text-zinc-300 text-xs font-mono',
                  text: badge,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
