import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'dialog.dart' show VoidCallback;
import 'icons.dart';

/// Descriptor for a single command item in the command palette.
class CommandItemConfig {
  final String label;
  final String? group;
  final String? shortcut;
  final String? icon;
  final VoidCallback onSelect;
  final bool disabled;

  const CommandItemConfig({
    required this.label,
    this.group,
    this.shortcut,
    this.icon,
    required this.onSelect,
    this.disabled = false,
  });
}

/// Configuration descriptor for an active command palette overlay.
class CommandPaletteConfig {
  final List<CommandItemConfig> items;
  final String placeholder;
  final VoidCallback? onClose;

  CommandPaletteConfig({
    required this.items,
    this.placeholder = 'Type a command or search...',
    this.onClose,
  });
}

/// Global active command palette state signal.
final Signal<CommandPaletteConfig?> activeCommandPalette =
    signal<CommandPaletteConfig?>(null);

/// Opens the global command palette overlay.
void openCommandPalette(
  List<({String label, String? group, VoidCallback onSelect})> items, {
  String placeholder = 'Type a command or search...',
  VoidCallback? onClose,
}) {
  activeCommandPalette.value = CommandPaletteConfig(
    items: items
        .map((item) => CommandItemConfig(
              label: item.label,
              group: item.group,
              onSelect: item.onSelect,
            ))
        .toList(),
    placeholder: placeholder,
    onClose: onClose,
  );
}

/// Opens the global command palette with full item configuration.
void openCommandPaletteDetailed({
  required List<CommandItemConfig> items,
  String placeholder = 'Type a command or search...',
  VoidCallback? onClose,
}) {
  activeCommandPalette.value = CommandPaletteConfig(
    items: items,
    placeholder: placeholder,
    onClose: onClose,
  );
}

/// Closes the currently active command palette.
void closeCommandPalette() {
  final cfg = activeCommandPalette.value;
  activeCommandPalette.value = null;
  cfg?.onClose?.call();
}

/// Root viewport component for rendering the global command palette modal overlay.
///
/// Mount this once near the root of the application.
BloomNode commandViewport() {
  final query = signal<String>('');
  final activeIndex = signal<int>(0);

  return Live(() {
    final config = activeCommandPalette.value;
    if (config == null) return const Fragment(children: []);

    final search = query.value.trim().toLowerCase();
    final filtered = config.items.where((item) {
      if (search.isEmpty) return true;
      return item.label.toLowerCase().contains(search) ||
          (item.group != null && item.group!.toLowerCase().contains(search));
    }).toList();

    // Clamp active index
    if (activeIndex.value >= filtered.length && filtered.isNotEmpty) {
      activeIndex.value = filtered.length - 1;
    } else if (filtered.isEmpty) {
      activeIndex.value = 0;
    }

    // Group items
    final groups = <String, List<CommandItemConfig>>{};
    for (final item in filtered) {
      final grp = item.group ?? '';
      groups.putIfAbsent(grp, () => []).add(item);
    }

    return Div(
      className:
          'fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-start justify-center p-4 pt-[15vh]',
      onClick: (_) => closeCommandPalette(),
      children: [
        Div(
          attrs: const {
            'role': 'dialog',
            'aria-modal': 'true',
            'aria-label': 'Command palette',
          },
          className:
              'relative bg-[var(--card)] border border-[var(--border)] rounded-[var(--radius-lg)] '
              'shadow-[var(--shadow-overlay)] max-w-xl w-full flex flex-col overflow-hidden',
          onClick: (BloomEvent e) => e.stopPropagation(),
          children: [
            // Search Input Header
            Div(
              className:
                  'flex items-center gap-2.5 px-3 py-3 border-b border-[var(--border)]',
              children: [
                uiIcon('search', className: 'w-4 h-4 text-[var(--text-muted)] shrink-0'),
                El(
                  'input',
                  attrs: {
                    'type': 'text',
                    'placeholder': config.placeholder,
                    'value': query.value,
                    'autofocus': 'autofocus',
                    'aria-autocomplete': 'list',
                  },
                  className:
                      'w-full bg-transparent text-xs sm:text-sm text-[var(--text)] placeholder-[var(--text-muted)] '
                      'focus:outline-none border-none p-0',
                  on: {
                    'input': (BloomEvent e) {
                      query.value = e.value ?? '';
                      activeIndex.value = 0;
                    },
                    'keydown': (BloomEvent e) {
                      if (e.key == 'Escape') {
                        e.preventDefault();
                        closeCommandPalette();
                      } else if (e.key == 'ArrowDown') {
                        e.preventDefault();
                        if (activeIndex.value < filtered.length - 1) {
                          activeIndex.value++;
                        }
                      } else if (e.key == 'ArrowUp') {
                        e.preventDefault();
                        if (activeIndex.value > 0) {
                          activeIndex.value--;
                        }
                      } else if (e.key == 'Enter') {
                        e.preventDefault();
                        if (filtered.isNotEmpty &&
                            activeIndex.value < filtered.length) {
                          final selectedItem = filtered[activeIndex.value];
                          if (!selectedItem.disabled) {
                            closeCommandPalette();
                            selectedItem.onSelect();
                          }
                        }
                      }
                    },
                  },
                ),
                El(
                  'button',
                  attrs: const {'type': 'button', 'aria-label': 'Close'},
                  className:
                      'text-[var(--text-muted)] hover:text-[var(--text)] p-1 rounded-[var(--radius-sm)] cursor-pointer',
                  onClick: (_) => closeCommandPalette(),
                  children: [uiIcon('x', className: 'w-3.5 h-3.5')],
                ),
              ],
            ),
            // Results list
            Div(
              className: 'max-h-72 overflow-y-auto p-1.5 flex flex-col gap-1',
              children: [
                if (filtered.isEmpty)
                  Div(
                    className:
                        'py-8 text-center text-xs text-[var(--text-muted)]',
                    text: 'No commands found.',
                  )
                else
                  ...groups.entries.expand((entry) {
                    final groupName = entry.key;
                    final groupItems = entry.value;

                    return [
                      if (groupName.isNotEmpty)
                        Div(
                          className:
                              'px-2 pt-2 pb-1 text-[10px] font-semibold tracking-wider uppercase text-[var(--text-muted)]',
                          text: groupName,
                        ),
                      ...groupItems.map((item) {
                        final overallIndex = filtered.indexOf(item);
                        final isSelected = overallIndex == activeIndex.value;

                        return El(
                          'button',
                          attrs: {
                            'type': 'button',
                            'role': 'option',
                            'aria-selected': isSelected ? 'true' : 'false',
                          },
                          className: cn([
                            'w-full flex items-center justify-between px-2.5 py-2 rounded-[var(--radius-sm)] text-xs text-left transition-colors cursor-pointer select-none',
                            isSelected
                                ? 'bg-[var(--bg-muted)] text-[var(--text)] font-medium'
                                : 'text-[var(--text)] hover:bg-[var(--bg-muted)]/50',
                            item.disabled
                                ? 'opacity-50 cursor-not-allowed pointer-events-none'
                                : '',
                          ]),
                          onClick: (_) {
                            if (!item.disabled) {
                              closeCommandPalette();
                              item.onSelect();
                            }
                          },
                          children: [
                            Div(
                              className: 'flex items-center gap-2',
                              children: [
                                if (item.icon != null)
                                  uiIcon(item.icon!, className: 'w-3.5 h-3.5 shrink-0 text-[var(--text-muted)]'),
                                Span(text: item.label),
                              ],
                            ),
                            if (item.shortcut != null)
                              Span(
                                className:
                                    'text-[10px] font-mono text-[var(--text-muted)] bg-[var(--bg-soft)] border border-[var(--border)] px-1.5 py-0.5 rounded',
                                text: item.shortcut!,
                              ),
                          ],
                        );
                      }),
                    ];
                  }),
              ],
            ),
          ],
        ),
      ],
    );
  });
}
