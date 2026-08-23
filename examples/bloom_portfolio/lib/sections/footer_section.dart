/// Footer section with social links, framework attribution, and return-to-top navigation.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import '../config.dart';
import '../plugins/lenis_scroll.dart';
import '../plugins/lucide_icons.dart';

/// Footer component.
class FooterComponent {
  BloomNode build() {
    return Footer(
      attrs: aria(role: AriaRole.contentinfo),
      className: 'border-t border-zinc-900 bg-zinc-950/80 py-12 px-4 sm:px-6 lg:px-8',
      children: [
        Div(
          className:
              'max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6',
          children: [
            // Left: Copyright and persona branding
            Div(
              className: 'flex flex-col sm:flex-row items-center gap-2 sm:gap-4 text-xs font-mono text-zinc-500',
              children: [
                Span(
                  className: 'text-zinc-300 font-semibold',
                  text: '© 2026 ${PortfolioPersona.name}',
                ),
                Span(className: 'hidden sm:inline text-zinc-700', text: '•'),
                Span(
                  text: 'Built with Bloom JS Native & Pure Dart AST',
                ),
              ],
            ),

            // Center / Right: Social Shortcuts & Back to top
            Div(
              className: 'flex items-center gap-4',
              children: [
                _socialIcon(
                  href: PortfolioPersona.github,
                  icon: LucideIconName.github,
                  label: 'Alex Rivera on GitHub',
                ),
                _socialIcon(
                  href: PortfolioPersona.linkedin,
                  icon: LucideIconName.linkedin,
                  label: 'Alex Rivera on LinkedIn',
                ),
                _socialIcon(
                  href: PortfolioPersona.twitter,
                  icon: LucideIconName.twitter,
                  label: 'Alex Rivera on X (Twitter)',
                ),

                // Back to Top Button
                Button(
                  attrs: {
                    'type': 'button',
                    ...aria(label: 'Scroll back to the top of the portfolio'),
                  },
                  className:
                      'ml-2 p-2 rounded-lg bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-zinc-400 hover:text-zinc-100 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                  onClick: (_) => LenisScroll.scrollTo('#hero', offset: 0),
                  children: [
                    Raw(LucideIcons.svg(LucideIconName.arrowUpRight, className: 'w-4 h-4 -rotate-45')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _socialIcon({
    required String href,
    required LucideIconName icon,
    required String label,
  }) {
    return A(
      href: href,
      target: '_blank',
      rel: 'noopener noreferrer',
      className:
          'p-2 rounded-lg text-zinc-400 hover:text-zinc-100 hover:bg-zinc-900 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
      attrs: aria(label: label),
      children: [
        Raw(LucideIcons.svg(icon, className: 'w-4 h-4')),
      ],
    );
  }
}
