import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Semantic `<table>` wrapper container primitive.
BloomNode table({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: 'relative w-full overflow-x-auto rounded-[var(--radius-md)] border border-[var(--border)]',
    children: [
      El(
        'table',
        className: cn(['w-full caption-bottom text-sm text-[var(--text)]', extraClassName]),
        children: children,
      ),
    ],
  );
}

/// Semantic `<thead>` table header element.
BloomNode tableHeader({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return El(
    'thead',
    className: cn(['[&_tr]:border-b bg-[var(--bg-soft)] border-[var(--border)]', extraClassName]),
    children: children,
  );
}

/// Semantic `<tbody>` table body element.
BloomNode tableBody({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return El(
    'tbody',
    className: cn(['[&_tr:last-child]:border-0', extraClassName]),
    children: children,
  );
}

/// Semantic `<tfoot>` table footer element.
BloomNode tableFooter({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return El(
    'tfoot',
    className: cn(['border-t border-[var(--border)] bg-[var(--muted)]/50 font-medium', extraClassName]),
    children: children,
  );
}

/// Semantic `<tr>` table row element.
BloomNode tableRow({
  required List<BloomNode> children,
  String extraClassName = '',
  BloomEventHandler? onClick,
}) {
  return El(
    'tr',
    className: cn([
      'border-b border-[var(--border)] transition-colors hover:bg-[var(--bg-muted)]/50',
      extraClassName,
    ]),
    onClick: onClick,
    children: children,
  );
}

/// Semantic `<th>` table header cell element.
BloomNode tableHead({
  String? text,
  List<BloomNode>? children,
  String extraClassName = '',
  int? colSpan,
  int? rowSpan,
}) {
  return El(
    'th',
    attrs: {
      if (colSpan != null) 'colspan': '$colSpan',
      if (rowSpan != null) 'rowspan': '$rowSpan',
    },
    className: cn([
      'h-10 px-4 text-left align-middle font-medium text-[var(--text-muted)] whitespace-nowrap text-xs sm:text-sm',
      extraClassName,
    ]),
    children: [
      if (text != null) Text(text),
      if (children != null) ...children,
    ],
  );
}

/// Semantic `<td>` table data cell element.
BloomNode tableCell({
  String? text,
  List<BloomNode>? children,
  String extraClassName = '',
  int? colSpan,
  int? rowSpan,
}) {
  return El(
    'td',
    attrs: {
      if (colSpan != null) 'colspan': '$colSpan',
      if (rowSpan != null) 'rowspan': '$rowSpan',
    },
    className: cn(['p-4 align-middle whitespace-nowrap text-xs sm:text-sm', extraClassName]),
    children: [
      if (text != null) Text(text),
      if (children != null) ...children,
    ],
  );
}

/// Semantic `<caption>` table caption element.
BloomNode tableCaption({
  required String text,
  String extraClassName = '',
}) {
  return El(
    'caption',
    className: cn(['mt-4 text-xs text-[var(--text-muted)]', extraClassName]),
    text: text,
  );
}
