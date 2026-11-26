import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Date picker input + quick calendar popover control.
BloomNode datePicker({
  Signal<DateTime?>? selected,
  String placeholder = 'Pick a date',
  void Function(DateTime date)? onSelect,
  String extraClassName = '',
}) {
  final current = selected ?? signal<DateTime?>(null);

  String formatDate(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  return Div(
    className: cn([
      'inline-flex items-center gap-2 rounded-[var(--radius-md)] border border-[var(--border)] '
          'bg-[var(--bg)] px-3 py-1.5 text-sm text-[var(--text)]',
      extraClassName,
    ]),
    children: [
      uiIcon('calendar', className: 'w-4 h-4 text-[var(--text-muted)]'),
      Live(() => Input(
            type: 'date',
            value: formatDate(current.value),
            attrs: {
              'aria-label': placeholder,
              'placeholder': placeholder,
            },
            className:
                'bg-transparent text-sm text-[var(--text)] focus:outline-none',
            onChange: (e) {
              final raw = e.value;
              if (raw == null || raw.isEmpty) {
                current.value = null;
                return;
              }
              final parsed = DateTime.tryParse(raw);
              if (parsed != null) {
                current.value = parsed;
                onSelect?.call(parsed);
              }
            },
          )),
    ],
  );
}
