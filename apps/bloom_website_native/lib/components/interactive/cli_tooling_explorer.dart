import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

final activeCmdId = signal('create');
final cliCopied = signal(false);

BloomNode cliToolingExplorer() {
  final commands = const [
    (
      'create',
      r'$ bloom create my_app',
      'Scaffold Project Structure',
      'Scaffolds opinionated project structure, bloom.yaml, boot sequence, and initial file-system routes.',
      [
        '✔ Creating Bloom app in ./my_app',
        '✔ Initializing bloom.yaml configuration',
        '✔ Generating route table (index.dart, _layout.dart)',
        '✔ Setting up thin DI container & signals state',
        '✔ Done in 240ms! Run "cd my_app && bloom dev" to start.',
      ],
    ),
    (
      'dev',
      r'$ bloom dev',
      'Expo-Style Dev Orchestration',
      'Expo-style dev orchestration with wireless pairing, device selection, hot reload, and diagnostics.',
      [
        '✔ Target: iPhone 16 Pro Simulator & Connected Pixel 9',
        '✔ Hot reload active on port 4321',
        '✔ Signals dependency graph initialized (60fps)',
        '✔ Watching /lib/app/routes for AST changes...',
        '✔ Ready! Press [r] to hot reload, [q] to quit.',
      ],
    ),
    (
      'doctor',
      r'$ bloom doctor',
      'System Diagnostics',
      'Diagnostics check for Flutter, Dart, Android SDK, Xcode, CocoaPods, and native configurations.',
      [
        '✔ [✓] Flutter 3.29.0 • channel stable',
        '✔ [✓] Dart 3.7.0',
        '✔ [✓] Android toolchain - develop for Android devices (SDK 34.0.0)',
        '✔ [✓] Xcode 16.2 - develop for iOS (iOS SDK 18.2)',
        '✔ [✓] Shorebird OTA CLI v1.2.0 active',
        '✔ All systems operational! Zero issues found.',
      ],
    ),
    (
      'generate',
      r'$ bloom generate',
      'Deterministic AST Code Gen',
      'Generates pages, routes, controllers, query models, and service abstractions deterministically.',
      [
        '✔ Scanning /lib/app/routes (14 files found)',
        '✔ Parsing controller signal dependencies',
        '✔ Generated lib/bloom.g.dart (1,240 lines)',
        '✔ Route table re-compiled in 34ms',
        '✔ Code generation complete.',
      ],
    ),
  ];

  return Div(
    className: 'max-w-5xl mx-auto space-y-6 text-left',
    children: [
      // Command Selector Tabs
      Div(
        className: 'grid grid-cols-2 md:grid-cols-4 gap-3',
        children: [
          for (final (id, cmd, shortDesc, _, _) in commands)
            Live(() {
              final isActive = activeCmdId.value == id;
              return Button(
                attrs: {'type': 'button'},
                onClick: (_) => activeCmdId.value = id,
                className:
                    'p-4 rounded-2xl text-left transition-all duration-200 border cursor-pointer ${isActive ? 'bg-white text-slate-950 border-white shadow-xl font-black scale-[1.02]' : 'bg-slate-950/90 dark:bg-black text-slate-300 hover:text-white hover:border-zinc-700 border-slate-800 dark:border-zinc-800'}',
                children: [
                  Div(
                    className:
                        'text-[11px] font-mono font-bold tracking-tight mb-1 '
                        'text-purple-400',
                    text: '${cmd.split(' ')[0]} ${cmd.split(' ')[1]}',
                  ),
                  Div(
                    className: 'text-xs font-black truncate',
                    text: shortDesc,
                  ),
                ],
              );
            }),
        ],
      ),

      // Terminal Sandbox Display
      Div(
        className:
            'rounded-3xl overflow-hidden bg-black border '
            'border-zinc-800 shadow-2xl font-mono text-xs',
        children: [
          // Terminal Header
          Div(
            className:
                'flex items-center justify-between px-5 py-4 '
                'bg-zinc-900/90 border-b border-zinc-800',
            children: [
              Div(
                className: 'flex items-center gap-2',
                children: [
                  Div(className: 'w-3 h-3 rounded-full bg-rose-500/80'),
                  Div(className: 'w-3 h-3 rounded-full bg-amber-500/80'),
                  Div(className: 'w-3 h-3 rounded-full bg-emerald-500/80'),
                  Span(
                    className: 'ml-2 text-xs font-bold text-slate-400',
                    text: 'bloom-cli — zsh',
                  ),
                ],
              ),
              Live(() {
                final active = commands.firstWhere(
                  (c) => c.$1 == activeCmdId.value,
                  orElse: () => commands.first,
                );
                final isCopied = cliCopied.value;

                return Button(
                  attrs: {
                    'type': 'button',
                    'onclick':
                        "navigator.clipboard.writeText(`${active.$2.replaceAll('`', r'\`').replaceAll(r'$', r'\$')}`); window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Command Copied', message: 'Copied CLI command to clipboard.', type: 'emerald' } }));",
                  },
                  onClick: (_) {
                    cliCopied.value = true;
                    Future.delayed(const Duration(seconds: 2), () {
                      cliCopied.value = false;
                    });
                  },
                  className:
                      'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg '
                      'bg-slate-800 hover:bg-slate-700 text-slate-300 '
                      'text-[11px] font-bold transition-colors border '
                      'border-slate-700 cursor-pointer',
                  children: [
                    hugeIcon(
                      isCopied ? 'check' : 'copy',
                      className:
                          'w-3.5 h-3.5 ${isCopied ? 'text-emerald-400' : 'text-slate-400'}',
                    ),
                    Span(text: isCopied ? 'Copied!' : 'Copy'),
                  ],
                );
              }),
            ],
          ),

          // Terminal Content Body
          Live(() {
            final active = commands.firstWhere(
              (c) => c.$1 == activeCmdId.value,
              orElse: () => commands.first,
            );

            return Div(
              className: 'p-6 sm:p-8 space-y-4 text-slate-200 leading-relaxed',
              children: [
                Div(
                  className:
                      'flex items-center gap-2 text-purple-400 font-bold '
                      'text-sm',
                  children: [
                    hugeIcon(
                      'code',
                      className: 'w-4 h-4 text-teal-400 shrink-0',
                    ),
                    Span(text: active.$2),
                  ],
                ),
                Div(
                  className:
                      'p-3 rounded-xl bg-slate-900/80 text-slate-400 text-xs '
                      'border border-slate-800',
                  text: active.$4,
                ),
                Div(
                  className: 'space-y-2 pt-2 text-xs font-mono',
                  children: [
                    for (final log in active.$5)
                      Div(
                        className:
                            'flex items-center gap-2 ${log.contains('✔') ? 'text-emerald-400' : 'text-slate-300'}',
                        children: [
                          Span(
                            className: 'text-slate-600 select-none',
                            text: '>',
                          ),
                          Span(text: log),
                        ],
                      ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    ],
  );
}
