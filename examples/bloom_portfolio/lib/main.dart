/// Bloom Portfolio showcase application entrypoint.
///
/// Mounts the single-page portfolio layout into `#app`, initializes
/// SEO head metadata with `bloom_seo`, and boots the Lenis smooth-scroll coordinator.
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:bloom_seo/bloom_seo.dart';

import 'config.dart';
import 'plugins/lenis_scroll.dart';
import 'sections/about_section.dart';
import 'sections/contact_section.dart';
import 'sections/footer_section.dart';
import 'sections/github_section.dart';
import 'sections/hero_section.dart';
import 'sections/navbar.dart';
import 'sections/projects_section.dart';

/// Top-level SEO metadata coordinator.
final HeadManager headManager = HeadManager(
  initialTitle: '${PortfolioPersona.name} — ${PortfolioPersona.role}',
  initialDescription: PortfolioPersona.tagline,
  initialOgTitle: '${PortfolioPersona.name} — Systems & Full-Stack Engineer',
  initialOgDescription: PortfolioPersona.tagline,
  initialOgType: 'website',
  initialOgUrl: 'https://alexrivera.dev',
  initialOgImage: PortfolioPersona.portraitUrl,
  initialTwitterCard: 'summary_large_image',
);

void main() {
  // Initialize smooth momentum scrolling via Lenis
  LenisScroll.init();

  // Instantiate high-cohesion section components
  final navbar = NavbarComponent();
  final hero = HeroSectionComponent();
  final about = AboutSectionComponent();
  final projects = ProjectsSectionComponent();
  final github = GitHubSectionComponent();
  final contact = ContactSectionComponent();
  final footer = FooterComponent();

  // Root single-page layout tree
  final app = Div(
    className:
        'min-h-screen flex flex-col bg-zinc-950 text-zinc-100 selection:bg-indigo-500 selection:text-white',
    children: [
      navbar.build(),
      Main(
        attrs: aria(role: AriaRole.main, label: 'Portfolio Content'),
        className: 'flex-1 flex flex-col',
        children: [
          hero.build(),
          about.build(),
          projects.build(),
          github.build(),
          contact.build(),
        ],
      ),
      footer.build(),
    ],
  );

  // Mount declarative AST descriptor tree directly into the browser DOM
  mount(app, '#app');
}
