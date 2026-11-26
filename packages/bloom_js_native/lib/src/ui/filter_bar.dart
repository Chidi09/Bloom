import '../framework.dart';
import '../signals.dart';
import 'cn.dart';

/// Filter chip option for [filterBar].
class FilterChipOption {
  /// Filter key value.
  final String value;

  /// Human-readable chip label.
  final String label;

  /// Optional count badge rendered beside [label].
  final int? count;

  /// Creates a [FilterChipOption].
  const FilterChipOption({
    required this.value,
    required this.label,
    this.count,
  });
}

/// Interactive row of toggleable filter chips with an optional clear button.
BloomNode filterBar({
  required List<FilterChipOption> options,
  required Signal<Set<String>> selected,
  bool showClear = true,
  String clearLabel = 'Clear',
  String extraClassName = '',
}) {
  return Live(() {
    final active = selected.value;
    return Div(
      attrs: const {'role': 'group', 'aria-label': 'Filters'},
      className: cn(['flex flex-wrap items-center gap-2', extraClassName]),
      children: [
        for (final opt in options)
          Button(
            attrs: {
              'type': 'button',
              'data-filter-value': opt.value,
              'aria-pressed': active.contains(opt.value) ? 'true' : 'false',
            },
            className: cn([
              'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border transition-colors',
              active.contains(opt.value)
                  ? 'border-[var(--primary)] bg-[var(--primary)] text-[var(--primary-foreground)]'
                  : 'border-[var(--border)] bg-[var(--bg)] text-[var(--text-muted)] hover:bg-[var(--bg-muted)]',
            ]),
            onClick: (_) {
              final next = Set<String>.of(selected.value);
              if (!next.add(opt.value)) {
                next.remove(opt.value);
              }
              selected.value = next;
            },
            children: [
              Span(text: opt.label),
              if (opt.count != null)
                Span(
                  className: 'opacity-75 font-mono',
                  text: '${opt.count}',
                ),
            ],
          ),
        if (showClear && active.isNotEmpty)
          Button(
            attrs: const {'type': 'button'},
            className:
                'px-2.5 py-1 text-xs text-[var(--text-muted)] hover:text-[var(--text)]',
            onClick: (_) => selected.value = <String>{},
            text: clearLabel,
          ),
      ],
    );
  });
}
