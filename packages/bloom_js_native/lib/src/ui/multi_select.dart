import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Option item for [multiSelect].
class MultiSelectOption {
  /// Value stored in the selected list.
  final String value;

  /// Human-readable display label.
  final String label;

  /// Creates a [MultiSelectOption].
  const MultiSelectOption({
    required this.value,
    required this.label,
  });
}

/// Multi-value selection control with chip summary and toggleable dropdown.
BloomNode multiSelect({
  required List<MultiSelectOption> options,
  required Signal<List<String>> selected,
  String placeholder = 'Select items...',
  String extraClassName = '',
}) {
  final isOpen = signal<bool>(false);

  return Div(
    className: cn(['relative w-full', extraClassName]),
    children: [
      Button(
        attrs: const {'type': 'button', 'aria-haspopup': 'listbox'},
        reactiveAttrs: {
          'aria-expanded': () => isOpen.value ? 'true' : 'false',
        },
        className:
            'flex min-h-9 w-full items-center justify-between gap-2 rounded-[var(--radius-md)] '
            'border border-[var(--border)] bg-[var(--bg)] px-3 py-1.5 text-sm text-[var(--text)]',
        onClick: (_) => isOpen.value = !isOpen.value,
        children: [
          Live(() {
            final vals = selected.value;
            if (vals.isEmpty) {
              return Span(
                className: 'text-[var(--text-faint)]',
                text: placeholder,
              );
            }
            return Div(
              className: 'flex flex-wrap gap-1',
              children: [
                for (final v in vals)
                  Span(
                    className:
                        'inline-flex items-center px-2 py-0.5 rounded-[var(--radius-sm)] bg-[var(--bg-muted)] text-xs font-medium',
                    text: options
                            .where((o) => o.value == v)
                            .firstOrNull
                            ?.label ??
                        v,
                  ),
              ],
            );
          }),
          uiIcon('chevron-down', className: 'w-4 h-4 text-[var(--text-muted)] shrink-0'),
        ],
      ),
      Show(
        () => isOpen.value,
        child: Div(
          attrs: const {
            'role': 'listbox',
            'aria-multiselectable': 'true',
          },
          className:
              'mt-1 w-full rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--popover)] '
              'p-1.5 shadow-[var(--shadow-overlay)] space-y-0.5',
          children: [
            Live(() {
              final current = selected.value;
              return Div(
                className: 'space-y-0.5',
                children: [
                  for (final opt in options)
                    Button(
                      attrs: {
                        'type': 'button',
                        'role': 'option',
                        'aria-selected':
                            current.contains(opt.value) ? 'true' : 'false',
                      },
                      className: cn([
                        'flex w-full items-center justify-between px-2.5 py-1.5 text-sm rounded-[var(--radius-sm)] hover:bg-[var(--bg-muted)]',
                        if (current.contains(opt.value))
                          'bg-[var(--bg-muted)] font-medium',
                      ]),
                      onClick: (_) {
                        final next = List<String>.of(selected.value);
                        if (next.contains(opt.value)) {
                          next.remove(opt.value);
                        } else {
                          next.add(opt.value);
                        }
                        selected.value = next;
                      },
                      children: [
                        Span(text: opt.label),
                        if (current.contains(opt.value))
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
