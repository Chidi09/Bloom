import 'package:bloom_js_native/bloom_js_native.dart';
import 'huge_icons.dart';

BloomNode backToTop() {
  return Button(
    attrs: const {
      'id': 'back-to-top',
      'type': 'button',
      'aria-label': 'Scroll back to top',
      'onclick': "window.scrollTo({ top: 0, behavior: 'smooth' });",
    },
    className:
        'fixed bottom-6 right-6 z-50 p-3 rounded-full bg-white/90 '
        'dark:bg-black/90 text-slate-800 dark:text-white '
        'shadow-xl border border-slate-200 dark:border-zinc-800 '
        'backdrop-blur-md opacity-0 translate-y-4 '
        'pointer-events-none transition-all duration-300 '
        'hover:scale-110 active:scale-95 group',
    children: [
      Span(
        className: 'block group-hover:-translate-y-0.5 transition-transform',
        children: [
          hugeIcon(
            'arrow-up',
            className: 'w-5 h-5 text-purple-600 dark:text-purple-400',
          ),
        ],
      ),
    ],
  );
}
