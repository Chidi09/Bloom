import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode scrollProgressRail() {
  return Aside(
    attrs: const {
      'id': 'scroll-progress-rail',
      'aria-label': 'Story Progress Rail',
    },
    className:
        'hidden xl:flex fixed right-6 top-1/2 -translate-y-1/2 '
        'z-40 flex-col items-center gap-6 pointer-events-none '
        'select-none',
    children: [
      Div(
        className: 'flex flex-col items-center gap-2',
        children: [
          Span(
            attrs: const {'id': 'rail-step-build'},
            className:
                'text-[9px] font-mono font-bold uppercase tracking-widest '
                'transition-colors duration-300 text-purple-500 scale-110',
            text: 'BUILD',
          ),
          Span(
            attrs: const {'id': 'rail-step-ship'},
            className:
                'text-[9px] font-mono font-bold uppercase tracking-widest '
                'transition-colors duration-300 text-slate-400 '
                'dark:text-slate-600',
            text: 'SHIP',
          ),
          Span(
            attrs: const {'id': 'rail-step-bloom'},
            className:
                'text-[9px] font-mono font-bold uppercase tracking-widest '
                'transition-colors duration-300 text-slate-400 '
                'dark:text-slate-600',
            text: 'BLOOM',
          ),
        ],
      ),

      // Progress Track
      Div(
        className:
            'w-1.5 h-36 bg-slate-200 dark:bg-zinc-800 rounded-full '
            'overflow-hidden relative shadow-inner',
        children: [
          Div(
            attrs: const {'id': 'rail-progress-bar'},
            className:
                'w-full bg-gradient-to-b from-purple-500 via-blue-500 '
                'to-cyan-400 rounded-full transition-all duration-150 '
                'ease-out',
            style: 'height: 0%;',
          ),
        ],
      ),

      Span(
        attrs: const {'id': 'rail-percent-text'},
        className: 'text-[10px] font-mono text-slate-400 font-semibold',
        text: '0%',
      ),
    ],
  );
}
