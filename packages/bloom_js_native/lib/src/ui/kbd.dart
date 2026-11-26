import '../framework.dart';
import 'cn.dart';

/// Styled keyboard shortcut keycap (`<kbd>`).
BloomNode kbd({
  required String text,
  String extraClassName = '',
}) {
  return El(
    'kbd',
    className: cn([
      'inline-flex h-5 min-w-5 items-center justify-center rounded-[var(--radius-sm)] '
          'border border-[var(--border)] bg-[var(--bg-muted)] px-1.5 font-mono '
          'text-[11px] font-medium text-[var(--text-muted)] select-none',
      extraClassName,
    ]),
    text: text,
  );
}

/// Renders a keyboard shortcut combination as joined [kbd] keycaps.
BloomNode kbdGroup({
  required List<String> keys,
  String separator = '+',
  String extraClassName = '',
}) {
  final nodes = <BloomNode>[];
  for (var i = 0; i < keys.length; i++) {
    if (i > 0 && separator.isNotEmpty) {
      nodes.add(Span(
        className: 'text-xs text-[var(--text-faint)]',
        text: separator,
      ));
    }
    nodes.add(kbd(text: keys[i]));
  }
  return Span(
    className: cn(['inline-flex items-center gap-1', extraClassName]),
    children: nodes,
  );
}
