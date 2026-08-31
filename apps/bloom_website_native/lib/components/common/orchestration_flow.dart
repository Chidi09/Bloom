import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _FlowStep {
  final String step;
  final String title;
  final String subtitle;
  final String desc;
  final String icon;

  const _FlowStep({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.icon,
  });
}

const _steps = <_FlowStep>[
  _FlowStep(
    step: 'STEP 1',
    title: 'STANDARDIZE',
    subtitle: 'Conventions & Config',
    desc:
        'Opinionated project structure, bloom.yaml schema, and /routes '
        'directory conventions.',
    icon: 'folder',
  ),
  _FlowStep(
    step: 'STEP 2',
    title: 'WRAP',
    subtitle: 'Proven Ecosystem',
    desc:
        'Thin abstractions over go_router for navigation and signals for '
        'fine-grained reactivity.',
    icon: 'code',
  ),
  _FlowStep(
    step: 'STEP 3',
    title: 'GENERATE',
    subtitle: 'Deterministic AST',
    desc:
        'Automatic route table generation, typed parameters, and model '
        'serializers on file save.',
    icon: 'cpu',
  ),
  _FlowStep(
    step: 'STEP 4',
    title: 'ORCHESTRATE',
    subtitle: 'Unified Workflow',
    desc:
        'Single CLI for bloom create, bloom dev, doctor, testing, prebuild, '
        'and deploy.',
    icon: 'zap',
  ),
  _FlowStep(
    step: 'STEP 5',
    title: 'REPLACE GAPS',
    subtitle: 'Differentiated Core',
    desc:
        'Custom Bloom Data query caching and Bloom Go Dev Client where genuine '
        'ecosystem gaps exist.',
    icon: 'check-circle',
  ),
];

BloomNode orchestrationFlow() {
  return Div(
    className: 'w-full max-w-6xl mx-auto py-6 text-left',
    children: [
      // Desktop Horizontal Pipeline Flow
      Div(
        className: 'hidden lg:grid grid-cols-5 gap-4 relative',
        children: [
          // Animated Connecting Background Beam
          Div(
            className:
                'absolute top-[42px] left-[10%] right-[10%] h-1 bg-slate-200 '
                'dark:bg-zinc-800 -z-10 rounded-full overflow-hidden',
            children: [
              Div(
                className:
                    'w-full h-full bg-gradient-to-r from-slate-400 via-slate-500 '
                    'to-slate-700 dark:from-zinc-600 dark:via-zinc-500 '
                    'dark:to-zinc-400 animate-pulse',
              ),
            ],
          ),
          for (int i = 0; i < _steps.length; i++)
            _renderDesktopStep(_steps[i], i + 1),
        ],
      ),

      // Mobile Vertical Pipeline Flow
      Div(
        className:
            'grid grid-cols-1 gap-6 lg:hidden relative pl-6 border-l-2 '
            'border-slate-300 dark:border-zinc-800 ml-4',
        children: [
          for (int i = 0; i < _steps.length; i++)
            _renderMobileStep(_steps[i], i + 1),
        ],
      ),
    ],
  );
}

BloomNode _renderDesktopStep(_FlowStep item, int stepNumber) {
  return Div(
    className: 'flex flex-col items-center text-center group relative',
    children: [
      // Step Node Circle
      Div(
        className:
            'w-20 h-20 rounded-3xl border-2 border-slate-300 dark:border-zinc-800 '
            'bg-white/60 dark:bg-black backdrop-blur-xl flex items-center '
            'justify-center mb-4 transition-all duration-300 group-hover:scale-110 '
            'group-hover:-translate-y-1 shadow-lg relative',
        children: [
          hugeIcon(item.icon, className: 'w-8 h-8 text-purple-400'),
          Span(
            className:
                'absolute -top-2 -right-2 w-6 h-6 rounded-full bg-purple-600 '
                'text-white font-mono text-[10px] font-bold flex items-center '
                'justify-center shadow',
            text: '$stepNumber',
          ),
        ],
      ),

      // Step Info Card
      Div(
        className:
            'glass-panel p-4 rounded-2xl w-full border border-slate-200/60 '
            'dark:border-white/10 dark:bg-black group-hover:border-slate-400 '
            'dark:group-hover:border-slate-500 transition-colors',
        children: [
          Span(
            className:
                'text-[9px] font-mono font-bold text-slate-400 uppercase '
                'tracking-widest block mb-0.5',
            text: item.step,
          ),
          H4(
            className:
                'font-black text-sm text-slate-900 dark:text-white tracking-tight '
                'mb-1',
            text: item.title,
          ),
          Span(
            className:
                'text-[10px] font-mono text-slate-500 dark:text-slate-400 '
                'font-semibold block mb-2',
            text: item.subtitle,
          ),
          P(
            className:
                'text-[11px] text-slate-600 dark:text-slate-400 leading-relaxed '
                'font-sans',
            text: item.desc,
          ),
        ],
      ),
    ],
  );
}

BloomNode _renderMobileStep(_FlowStep item, int stepNumber) {
  return Div(
    className: 'relative group',
    children: [
      // Bullet Node
      Div(
        className:
            'absolute -left-[35px] top-4 w-7 h-7 rounded-full bg-purple-600 '
            'text-white font-mono text-xs font-bold flex items-center '
            'justify-center shadow',
        text: '$stepNumber',
      ),
      Div(
        className:
            'glass-panel p-5 rounded-2xl border border-slate-200/60 '
            'dark:border-white/10 dark:bg-black text-left',
        children: [
          Div(
            className: 'flex items-center gap-3 mb-2',
            children: [
              Div(
                className:
                    'p-2 rounded-xl border border-slate-300 dark:border-zinc-800 '
                    'bg-white/60 dark:bg-black',
                children: [
                  hugeIcon(item.icon, className: 'w-5 h-5 text-purple-400'),
                ],
              ),
              Div(
                children: [
                  Span(
                    className:
                        'text-[9px] font-mono font-bold text-slate-400 uppercase '
                        'tracking-widest block',
                    text: item.step,
                  ),
                  H4(
                    className:
                        'font-black text-base text-slate-900 dark:text-white '
                        'leading-none',
                    text: item.title,
                  ),
                ],
              ),
            ],
          ),
          P(
            className:
                'text-xs text-slate-600 dark:text-slate-400 leading-relaxed '
                'mt-2 font-sans',
            text: item.desc,
          ),
        ],
      ),
    ],
  );
}
