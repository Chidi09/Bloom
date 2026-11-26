import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Option item displayed in [combobox].
class ComboboxOption {
  /// Machine value submitted or stored when selected.
  final String value;

  /// Human-readable option label.
  final String label;

  /// Whether this option cannot be selected.
  final bool disabled;

  /// Creates a [ComboboxOption].
  const ComboboxOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });
}

/// Searchable autocomplete select primitive.
BloomNode combobox({
  required List<ComboboxOption> options,
  Signal<String?>? selected,
  String placeholder = 'Select option...',
  String searchPlaceholder = 'Search...',
  String emptyText = 'No results found.',
  void Function(String value)? onSelect,
  String extraClassName = '',
}) {
  final current = selected ?? signal<String?>(null);
  final isOpen = signal<bool>(false);
  final query = signal<String>('');

  return Div(
    className: cn(['relative w-full', extraClassName]),
    children: [
      Button(
        attrs: const {
          'type': 'button',
          'role': 'combobox',
        },
        reactiveAttrs: {
          'aria-expanded': () => isOpen.value ? 'true' : 'false',
        },
        className:
            'flex h-9 w-full items-center justify-between rounded-[var(--radius-md)] border border-[var(--border)] '
            'bg-[var(--bg)] px-3 py-2 text-sm text-[var(--text)] hover:bg-[var(--bg-soft)]',
        onClick: (_) => isOpen.value = !isOpen.value,
        children: [
          Live(() {
            final selectedVal = current.value;
            final match =
                options.where((o) => o.value == selectedVal).firstOrNull;
            return Span(
              className: match == null
                  ? 'text-[var(--text-faint)] truncate'
                  : 'text-[var(--text)] truncate',
              text: match?.label ?? placeholder,
            );
          }),
          uiIcon('chevron-down', className: 'w-4 h-4 text-[var(--text-muted)]'),
        ],
      ),
      Show(
        () => isOpen.value,
        child: Div(
          attrs: const {'role': 'listbox'},
          className:
              'mt-1 w-full rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--popover)] '
              'text-[var(--popover-foreground)] shadow-[var(--shadow-overlay)] p-2 space-y-1',
          children: [
            Input(
              type: 'text',
              placeholder: searchPlaceholder,
              className:
                  'w-full h-8 px-2.5 text-sm rounded-[var(--radius-sm)] border border-[var(--border)] '
                  'bg-[var(--bg)] text-[var(--text)] focus:outline-none focus:ring-2 focus:ring-[var(--ring)]',
              onInput: (e) => query.value = e.value ?? '',
            ),
            Live(() {
              final q = query.value.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? options
                  : options
                      .where((o) => o.label.toLowerCase().contains(q))
                      .toList();
              if (filtered.isEmpty) {
                return P(
                  className:
                      'py-3 text-center text-xs text-[var(--text-muted)]',
                  text: emptyText,
                );
              }
              return Div(
                className: 'max-h-52 overflow-y-auto space-y-0.5',
                children: [
                  for (final opt in filtered)
                    Button(
                      attrs: {
                        'type': 'button',
                        'role': 'option',
                        'data-value': opt.value,
                        'aria-selected':
                            current.value == opt.value ? 'true' : 'false',
                        if (opt.disabled) 'disabled': 'true',
                      },
                      className: cn([
                        'flex w-full items-center justify-between px-2.5 py-1.5 text-sm rounded-[var(--radius-sm)] text-left',
                        opt.disabled
                            ? 'opacity-50 pointer-events-none'
                            : 'hover:bg-[var(--bg-muted)] cursor-pointer',
                        if (current.value == opt.value)
                          'bg-[var(--bg-muted)] font-medium',
                      ]),
                      onClick: opt.disabled
                          ? null
                          : (_) {
                              current.value = opt.value;
                              isOpen.value = false;
                              query.value = '';
                              onSelect?.call(opt.value);
                            },
                      children: [
                        Span(text: opt.label),
                        if (current.value == opt.value)
                          uiIcon('check', className: 'w-4 h-4 text-[var(--primary)]'),
                      ],
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    ],
  );
}
