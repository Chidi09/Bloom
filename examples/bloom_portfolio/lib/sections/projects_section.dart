/// Featured projects showcase section with responsive image rendering and GSAP scroll reveal.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import '../data/projects.dart';
import '../plugins/gsap.dart';
import '../plugins/lucide_icons.dart';

/// Projects showcase grid component.
class ProjectsSectionComponent {
  BloomNode build() {
    return Mount(
      Section(
        attrs: {
          'id': 'projects',
          ...aria(
            role: AriaRole.region,
            label: 'Featured Engineering Projects',
          ),
        },
        className: 'py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-zinc-900',
        children: [
          // Section Header
          Div(
            className: 'flex flex-col md:flex-row md:items-end justify-between mb-16 gap-4',
            children: [
              Div(
                children: [
                  Span(
                    className:
                        'font-mono text-xs text-indigo-400 font-semibold tracking-widest uppercase mb-2 block',
                    text: '02. Selected Work',
                  ),
                  H2(
                    className: 'text-3xl sm:text-4xl font-bold tracking-tight text-zinc-50',
                    text: 'Featured Engineering Projects',
                  ),
                ],
              ),
              P(
                className: 'text-zinc-400 text-sm max-w-md',
                text:
                    'Systems, compilers, and cloud infrastructure engineered for resilience, deterministic latency, and mechanical sympathy.',
              ),
            ],
          ),

          // Responsive 6-Project Grid (1 col mobile, 2 cols tablet, 3 cols desktop)
          Div(
            className: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8',
            children: featuredProjects.map(_buildProjectCard).toList(),
          ),
        ],
      ),
      onMount: () {
        // Trigger GSAP stagger animation on mounted project cards
        Gsap.staggerReveal('.project-card', duration: 0.6, stagger: 0.08);
      },
    );
  }

  BloomNode _buildProjectCard(PortfolioProject project) {
    return Article(
      attrs: {
        'id': 'project-${project.id}',
        ...aria(
          role: AriaRole.article,
          label: 'Project: ${project.title}',
        ),
      },
      className:
          'project-card flex flex-col rounded-2xl bg-zinc-900/40 border border-zinc-800/80 hover:border-zinc-700/90 overflow-hidden group transition-all duration-300 hover:shadow-xl hover:shadow-indigo-950/20 hover:-translate-y-1',
      children: [
        // Project Cover Image using Bloom Responsive Image Descriptor (bloomImage)
        Div(
          className: 'relative overflow-hidden aspect-video bg-zinc-950 border-b border-zinc-800/60',
          children: [
            bloomImage(
              src: project.imageUrl,
              alt: project.imageAlt,
              width: 800,
              height: 450,
              aspectRatio: '16/9',
              fit: ImageFit.cover,
              className:
                  'w-full h-full object-cover group-hover:scale-105 transition-transform duration-500',
              placeholder: '#09090b',
            ),
            // Category Badge Overlay
            Div(
              className: 'absolute top-3 left-3',
              children: [
                Span(
                  className:
                      'px-2.5 py-1 rounded-md text-[11px] font-mono font-medium backdrop-blur-md bg-zinc-950/80 border border-zinc-800/90 text-indigo-300',
                  text: project.category,
                ),
              ],
            ),
          ],
        ),

        // Card Content
        Div(
          className: 'p-6 flex-1 flex flex-col justify-between gap-6',
          children: [
            Div(
              className: 'flex flex-col gap-3',
              children: [
                H3(
                  className:
                      'text-lg font-bold text-zinc-100 group-hover:text-indigo-400 transition-colors leading-snug',
                  text: project.title,
                ),
                P(
                  className: 'text-zinc-400 text-sm leading-relaxed line-clamp-3',
                  text: project.description,
                ),
              ],
            ),

            Div(
              className: 'flex flex-col gap-4 pt-4 border-t border-zinc-800/60',
              children: [
                // Tech Tags List
                Div(
                  className: 'flex flex-wrap gap-1.5',
                  children: project.tags
                      .map(
                        (tag) => Span(
                          className:
                              'px-2 py-0.5 rounded bg-zinc-800/50 border border-zinc-700/40 text-zinc-300 text-[11px] font-mono',
                          text: tag,
                        ),
                      )
                      .toList(),
                ),

                // External Links
                Div(
                  className: 'flex items-center justify-between pt-1',
                  children: [
                    // GitHub Link
                    A(
                      href: project.githubUrl,
                      target: '_blank',
                      rel: 'noopener noreferrer',
                      className:
                          'inline-flex items-center gap-1.5 text-xs font-mono font-medium text-zinc-400 hover:text-zinc-100 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 rounded p-1',
                      attrs: aria(
                        label: 'View source code for ${project.title} on GitHub',
                      ),
                      children: [
                        Raw(LucideIcons.svg(LucideIconName.github, className: 'w-4 h-4')),
                        Span(text: 'Source'),
                      ],
                    ),

                    // Demo Link (if available)
                    if (project.demoUrl != null)
                      A(
                        href: project.demoUrl!,
                        target: '_blank',
                        rel: 'noopener noreferrer',
                        className:
                            'inline-flex items-center gap-1 text-xs font-mono font-medium text-indigo-400 hover:text-indigo-300 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 rounded p-1',
                        attrs: aria(
                          label: 'Launch live demo for ${project.title}',
                        ),
                        children: [
                          Span(text: 'Live Demo'),
                          Raw(LucideIcons.svg(LucideIconName.arrowUpRight, className: 'w-3.5 h-3.5')),
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
}
