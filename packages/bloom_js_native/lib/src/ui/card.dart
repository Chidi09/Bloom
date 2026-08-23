import '../framework.dart';
import 'cn.dart';

/// Card container primitive.
BloomNode card({
  required List<BloomNode> children,
  String extraClassName = '',
  Map<String, String> attrs = const {},
}) {
  return Div(
    attrs: attrs,
    className: cn([
      'rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--card)] '
      'text-[var(--card-foreground)] shadow-[var(--shadow-card)] flex flex-col overflow-hidden',
      extraClassName,
    ]),
    children: children,
  );
}

/// Header section of a [card].
BloomNode cardHeader({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['flex flex-col gap-1.5 p-6', extraClassName]),
    children: children,
  );
}

/// Title element inside [cardHeader].
BloomNode cardTitle({
  required String text,
  String extraClassName = '',
}) {
  return H3(
    className: cn([
      'text-lg font-semibold leading-tight tracking-tight text-[var(--text)]',
      extraClassName,
    ]),
    text: text,
  );
}

/// Secondary description element inside [cardHeader].
BloomNode cardDescription({
  required String text,
  String extraClassName = '',
}) {
  return P(
    className: cn(['text-sm text-[var(--text-muted)]', extraClassName]),
    text: text,
  );
}

/// Main body content section of a [card].
BloomNode cardContent({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['p-6 pt-0 flex-1', extraClassName]),
    children: children,
  );
}

/// Footer action section of a [card].
BloomNode cardFooter({
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['flex items-center p-6 pt-0', extraClassName]),
    children: children,
  );
}
