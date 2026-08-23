import '../framework.dart';
import 'cn.dart';

/// Layout container for grouping an input control with leading/trailing addons.
BloomNode inputGroup({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {'role': 'group'},
    className: cn([
      'relative flex items-center w-full rounded-[var(--radius-sm)] border border-[var(--border)] '
      'bg-[var(--bg)] shadow-sm focus-within:ring-2 focus-within:ring-[var(--ring)] '
      'focus-within:border-[var(--primary)] transition-colors overflow-hidden',
      extraClassName,
    ]),
    children: children,
  );
}

/// Addon container placed inside an [inputGroup].
BloomNode inputGroupAddon({
  required List<BloomNode> children,
  String align = 'left',
  String extraClassName = '',
}) {
  return Div(
    className: cn([
      'flex items-center px-3 text-xs sm:text-sm text-[var(--text-muted)] bg-[var(--muted)]/50 select-none shrink-0',
      align == 'left' ? 'border-r border-[var(--border)]' : 'border-l border-[var(--border)]',
      extraClassName,
    ]),
    children: children,
  );
}

/// Text label helper for [inputGroupAddon].
BloomNode inputGroupText({
  required String text,
  String extraClassName = '',
}) {
  return Span(
    className: cn(['text-xs sm:text-sm font-medium text-[var(--text-muted)]', extraClassName]),
    text: text,
  );
}
