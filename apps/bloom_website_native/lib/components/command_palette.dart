
import 'package:bloom_js_native/bloom_js_native.dart';

import 'huge_icons.dart';
import 'toast_system.dart' as site;

final isPaletteOpen = signal(false);
final searchQuery = signal('');

/// Browser clipboard hook. Assigned in `lib/main.dart` (the only file allowed
/// to touch real browser APIs); a no-op under SSR / VM tests.
void Function(String text) copyToClipboard = (_) {};

/// Focus hook for the palette search input. Assigned in `lib/main.dart`;
/// receives the mounted element (a real `HTMLInputElement` in the browser).
void Function(Object? inputElement) focusPaletteInput = (_) {};

void openPalette() {
  searchQuery.value = '';
  isPaletteOpen.value = true;
}

void closePalette() {
  isPaletteOpen.value = false;
}

final _inputRef = Ref<Object>();

class _Command {
  final String title;
  final String description;
  final String category;
  final String icon;

  /// 'route' navigates to a local native route, 'external' opens a new tab,
  /// 'copy' copies [target] to the clipboard with toast feedback.
  final String kind;
  final String target;

  const _Command(
    this.title,
    this.description,
    this.category,
    this.icon,
    this.kind,
    this.target,
  );
}

// Mirrors bloom-website/src/components/common/CommandPalette.tsx, limited to
// navigation targets that actually exist as routes in this native app.
const _commands = <_Command>[
  _Command('Hub', 'Platform overview & telemetry benchmarks', 'Navigation',
      'zap', 'route', '/'),
  _Command(
      'App (Client)',
      'Opinionated architecture, signals, and routing for Flutter',
      'Navigation',
      'cpu',
      'route',
      '/build'),
  _Command(
      'Server (Backend)',
      'Multi-isolate Dart backend, SQLite ORM, and OpenAPI 3.1',
      'Navigation',
      'server',
      'route',
      '/server'),
  _Command(
      'Cloud & CLI',
      'Over-the-air delta binary patches and Shorebird release channels',
      'Navigation',
      'rocket',
      'route',
      '/ship'),
  _Command(
      'UI Studio',
      '60+ shadcn-inspired accessible mobile primitives for Flutter',
      'Navigation',
      'sparkles',
      'route',
      '/bloom'),
  _Command(
      'Application Blocks',
      'Bloom UI primitives — the building blocks of every Bloom app',
      'Navigation',
      'layers',
      'route',
      '/blocks'),
  _Command(
      'Documentation Home',
      'Guides, tutorials, CLI references, and architecture specs on GitHub',
      'Docs',
      'code',
      'external',
      'https://github.com/Chidi09/Bloom'),
  _Command(
      'Pub.dev — bloom_js_native',
      'Package page, changelog, and scores on pub.dev',
      'Docs',
      'github',
      'external',
      'https://pub.dev/packages/bloom_js_native'),
  _Command(
      'Copy CLI Install Command',
      'Put "dart pub global activate bloom_cli" on your clipboard',
      'Actions',
      'terminal',
      'copy',
      'dart pub global activate bloom_cli'),
  _Command(
      'bloom ui add all (Copy source components)',
      'Put "bloom ui add all" on your clipboard to copy the component suite',
      'Actions',
      'copy',
      'copy',
      'bloom ui add all'),
];

BloomNode commandPaletteViewport() {
  // Only reads `isPaletteOpen` — typing in the search input must NOT rebuild
  // this subtree, otherwise the real <input> node is destroyed and focus is
  // dropped on every keystroke (COOKBOOK.md Section 20).
  return Live(() {
    if (!isPaletteOpen.value) return const Fragment(children: []);

    // onMount runs in a microtask after the modal DOM actually exists, which
    // is exactly when the input can be focused.
    return Mount(
      _paletteModal(),
      onMount: () {
        if (_inputRef.isMounted) focusPaletteInput(_inputRef.value);
      },
    );
  });
}


const _itemClassName =
    'w-full flex items-center justify-between p-3 rounded-xl '
    'hover:bg-zinc-900 text-zinc-300 hover:text-white '
    'transition-colors group text-left';

BloomNode _paletteModal() {
  return Div(
    attrs: const {
      'id': 'command-palette-modal',
      'role': 'dialog',
      'aria-modal': 'true',
      'aria-label': 'Command Palette',
    },
    className:
        'fixed inset-0 z-[100] flex items-start justify-center '
        'pt-20 px-4 bg-black/80 backdrop-blur-md animate-fadeIn',
    onClick: (e) {
      e.stopPropagation();
      closePalette();
    },
    children: [
      Div(
        className:
            'w-full max-w-xl rounded-2xl bg-zinc-950 border '
            'border-zinc-800 shadow-2xl overflow-hidden',
        onClick: (e) => e.stopPropagation(),
        children: [
          // Search Input Header — static nodes only; the input is never
          // rebuilt while the palette is open.
          Div(
            className:
                'flex items-center gap-3 px-4 py-3.5 border-b '
                'border-zinc-800',
            children: [
              hugeIcon('search', className: 'w-4 h-4 text-zinc-400'),
              RefNode(
                _inputRef,
                Input(
                  attrs: const {
                    'id': 'cmd-palette-input',
                    'autocomplete': 'off',
                    'spellcheck': 'false',
                  },
                  placeholder: 'Type a command or search pages...',
                  className:
                      'flex-1 bg-transparent border-none outline-none text-sm '
                      'text-white placeholder:text-zinc-500 font-sans',
                  onInput: (e) => searchQuery.value = e.value ?? '',
                ),
              ),
              Button(
                attrs: const {'type': 'button'},
                onClick: (_) => closePalette(),
                className:
                    'px-2 py-0.5 rounded bg-zinc-900 border border-zinc-800 '
                    'text-[10px] text-zinc-400 font-mono hover:text-white',
                text: 'ESC',
              ),
            ],
          ),

          // Filtered Items List — the only reactive part of the palette.
          Div(className: 'p-2 max-h-80 overflow-y-auto', children: [
            Live(() {
              final query = searchQuery.value.toLowerCase().trim();
              final filtered = _commands
                  .where(
                    (cmd) =>
                        query.isEmpty ||
                        cmd.title.toLowerCase().contains(query) ||
                        cmd.description.toLowerCase().contains(query),
                  )
                  .toList();

              if (filtered.isEmpty) {
                return Div(
                  className: 'py-8 text-center text-xs text-zinc-500 font-mono',
                  text: 'No matching commands found for "$query"',
                );
              }

              return Fragment(
                children: [for (final cmd in filtered) _commandItem(cmd)],
              );
            }),
          ]),

          // Footer
          Div(
            className:
                'px-4 py-2.5 border-t border-zinc-800 flex items-center '
                'justify-between text-[11px] text-zinc-500 font-mono',
            children: [
              Span(text: 'Tip: results filter as you type'),
              Span(
                className: 'flex items-center gap-1',
                children: [
                  El(
                    'kbd',
                    className:
                        'px-1.5 py-0.5 bg-zinc-800 rounded font-bold text-zinc-300',
                    text: '⌘K',
                  ),
                  Span(text: ' to toggle'),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

BloomNode _commandItem(_Command cmd) {
  if (cmd.kind == 'route') {
    return A(
      href: cmd.target,
      // The SPA link interceptor in main.dart turns this into
      // controller.navigate(); we only need to dismiss the palette.
      onClick: (_) => closePalette(),
      className: _itemClassName,
      children: _itemChildren(cmd),
    );
  }

  if (cmd.kind == 'external') {
    return A(
      href: cmd.target,
      attrs: const {'target': '_blank', 'rel': 'noopener noreferrer'},
      onClick: (_) => closePalette(),
      className: _itemClassName,
      children: _itemChildren(cmd),
    );
  }

  return Button(
    attrs: const {'type': 'button'},
    onClick: (_) {
      copyToClipboard(cmd.target);
      site.showToast(
        'Command Copied',
        'Run "${cmd.target}" in your terminal.',
        type: 'emerald',
      );
      closePalette();
    },
    className: _itemClassName,
    children: _itemChildren(cmd),
  );
}

List<BloomNode> _itemChildren(_Command cmd) {
  return [
    Div(
      className: 'flex items-center gap-3',
      children: [
        Div(
          className:
              'w-8 h-8 rounded-lg bg-zinc-900 group-hover:bg-zinc-800 '
              'flex items-center justify-center text-zinc-400 '
              'group-hover:text-purple-400 transition-colors',
          children: [hugeIcon(cmd.icon, className: 'w-4 h-4')],
        ),
        Div(
          children: [
            Span(
              className: 'text-sm font-semibold block text-white',
              text: cmd.title,
            ),
            Span(
              className: 'text-xs text-zinc-500 block',
              text: cmd.description,
            ),
          ],
        ),
      ],
    ),
    Div(
      className: 'flex items-center gap-2 shrink-0',
      children: [
        Span(
          className:
              'text-[10px] text-zinc-400 bg-zinc-900 px-2 py-0.5 rounded '
              'font-mono',
          text: cmd.category,
        ),
        hugeIcon(
          cmd.kind == 'external' ? 'arrow-up-right' : 'chevron-right',
          className:
              'w-3.5 h-3.5 text-zinc-600 group-hover:text-zinc-300 '
              'opacity-0 group-hover:opacity-100 transition-all',
        ),
      ],
    ),
  ];
}