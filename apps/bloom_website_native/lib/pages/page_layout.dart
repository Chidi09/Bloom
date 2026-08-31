import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/back_to_top.dart';
import '../components/footer.dart';
import '../components/navbar.dart';
import '../components/scroll_progress_rail.dart';
import '../design/tokens.dart';

BloomNode pageLayout({
  required String currentPath,
  String petalHighlight = 'all',
  String? nextChapterTitle,
  String? nextChapterLink,
  String? nextChapterSubtitle,
  required BloomNode child,
}) {
  return Div(
    className:
        'min-h-screen relative overflow-x-clip antialiased '
        'selection:bg-purple-500/30 bg-slate-50 dark:bg-black '
        'text-slate-900 dark:text-white flex flex-col '
        'justify-between',
    children: [
      // 1. Injected Global Tokens & Fonts
      fontStylesheetLink(),
      const Style(designTokensCss),

      // 2. Background System (Ambient Mesh + Grid Overlay)
      Div(
        className:
            'fixed inset-0 z-[-1] pointer-events-none bg-slate-50 '
            'dark:bg-black transition-colors duration-500',
      ),
      Div(className: 'grid-overlay'),

      // 3. Story Scroll Progress Rail
      scrollProgressRail(),

      // 4. Main Navigation Header
      navbar(currentPath: currentPath, petalHighlight: petalHighlight),

      // 5. Main Page Content
      Main(
        attrs: const {'id': 'top'},
        className: 'flex-1 flex flex-col relative z-10',
        children: [child],
      ),

      // 6. Page Footer with Narrative Cross-Link
      footer(
        nextChapterTitle: nextChapterTitle ?? 'Ship with Cloud OTA',
        nextChapterLink: nextChapterLink ?? '/ship',
        nextChapterSubtitle:
            nextChapterSubtitle ??
            'Push instant byte-patches to live apps without App Store review delays.',
      ),

      // 7. Page-local interactive shell islands. The command palette and
      // toast viewport are mounted once by lib/main.dart at the app root.
      // Mounting them here as well created duplicate modal IDs and overlays.
      backToTop(),

      // 8. Global Interaction Observer & Event Bridge Script
      El(
        'script',
        children: [
          Raw(r'''
(function() {
  function initInteractiveEffects() {
    // 1. Mouse glow positioning on cards
    if (window.matchMedia('(pointer: fine)').matches) {
      document.addEventListener('mousemove', (e) => {
        document.querySelectorAll('.mouse-glow-card').forEach((card) => {
          const rect = card.getBoundingClientRect();
          const x = e.clientX - rect.left;
          const y = e.clientY - rect.top;
          card.style.setProperty('--mouse-x', x + 'px');
          card.style.setProperty('--mouse-y', y + 'px');
        });
      });
    }

    // 2. IntersectionObserver for Blur-Fade Scroll Reveals
    const revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -40px 0px' }
    );
    document.querySelectorAll('.scroll-reveal').forEach((el) => {
      revealObserver.observe(el);
    });

    // 3. Scroll Progress Rail & Back to Top Scroll Handler
    function handleWindowScroll() {
      // Back to top visibility
      const btn = document.getElementById('back-to-top');
      if (btn) {
        if (window.scrollY > 300) {
          btn.classList.remove('opacity-0', 'translate-y-4', 'pointer-events-none');
          btn.classList.add('opacity-100', 'translate-y-0');
        } else {
          btn.classList.add('opacity-0', 'translate-y-4', 'pointer-events-none');
          btn.classList.remove('opacity-100', 'translate-y-0');
        }
      }

      // Rail progress calculation
      const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (totalHeight > 0) {
        const currentProgress = (window.scrollY / totalHeight) * 100;
        const bounded = Math.min(100, Math.max(0, currentProgress));

        const progressBar = document.getElementById('rail-progress-bar');
        const percentText = document.getElementById('rail-percent-text');
        const stepBuild = document.getElementById('rail-step-build');
        const stepShip = document.getElementById('rail-step-ship');
        const stepBloom = document.getElementById('rail-step-bloom');

        if (progressBar) progressBar.style.height = bounded + '%';
        if (percentText) percentText.textContent = Math.round(bounded) + '%';

        if (stepBuild && stepShip && stepBloom) {
          if (bounded > 66) {
            stepBloom.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-cyan-500 scale-110';
            stepShip.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
            stepBuild.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
          } else if (bounded > 33) {
            stepShip.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-blue-500 scale-110';
            stepBloom.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
            stepBuild.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
          } else {
            stepBuild.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-purple-500 scale-110';
            stepShip.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
            stepBloom.className = 'text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 text-slate-400 dark:text-slate-600';
          }
        }
      }
    }
    window.addEventListener('scroll', handleWindowScroll, { passive: true });
    handleWindowScroll();

    // 4. Keyboard Shortcuts (Cmd+K / Ctrl+K / ESC)
    document.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        window.dispatchEvent(new CustomEvent('bloom:open-cmd-palette'));
      }
    });

    // 5. Mobile Menu Helpers
    window.toggleBloomMobileMenu = function() {
      const menu = document.getElementById('mobile-menu');
      const backdrop = document.getElementById('mobile-menu-backdrop');
      const iconOpen = document.getElementById('menu-icon-open');
      const iconClose = document.getElementById('menu-icon-close');
      if (!menu) return;
      const isHidden = menu.classList.contains('hidden');
      if (isHidden) {
        menu.classList.remove('hidden');
        if (backdrop) backdrop.classList.remove('hidden');
        if (iconOpen) iconOpen.classList.add('hidden');
        if (iconClose) iconClose.classList.remove('hidden');
      } else {
        menu.classList.add('hidden');
        if (backdrop) backdrop.classList.add('hidden');
        if (iconOpen) iconOpen.classList.remove('hidden');
        if (iconClose) iconClose.classList.add('hidden');
      }
    };

    window.closeBloomMobileMenu = function() {
      const menu = document.getElementById('mobile-menu');
      const backdrop = document.getElementById('mobile-menu-backdrop');
      const iconOpen = document.getElementById('menu-icon-open');
      const iconClose = document.getElementById('menu-icon-close');
      if (!menu) return;
      menu.classList.add('hidden');
      if (backdrop) backdrop.classList.add('hidden');
      if (iconOpen) iconOpen.classList.remove('hidden');
      if (iconClose) iconClose.classList.add('hidden');
    };
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initInteractiveEffects);
  } else {
    initInteractiveEffects();
  }
  window.addEventListener('bloom:mounted', initInteractiveEffects);
})();
'''),
        ],
      ),
    ],
  );
}
