import '../framework.dart';
import 'cn.dart';

/// Layout orientation for [buttonGroup].
enum ButtonGroupOrientation {
  /// Arrange buttons side-by-side in a row.
  horizontal,

  /// Stack buttons vertically in a column.
  vertical,
}

/// Groups related buttons or controls with joined borders and focus layering.
BloomNode buttonGroup({
  required List<BloomNode> children,
  ButtonGroupOrientation orientation = ButtonGroupOrientation.horizontal,
  String ariaLabel = 'Button group',
  String extraClassName = '',
}) {
  final isVertical = orientation == ButtonGroupOrientation.vertical;
  return Div(
    attrs: {
      'role': 'group',
      'aria-label': ariaLabel,
      'data-orientation': isVertical ? 'vertical' : 'horizontal',
    },
    className: cn([
      'inline-flex w-fit items-stretch',
      isVertical
          ? 'flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:last-child)]:rounded-b-none [&>*:not(:first-child)]:-mt-px'
          : 'flex-row [&>*:not(:first-child)]:rounded-l-none [&>*:not(:last-child)]:rounded-r-none [&>*:not(:first-child)]:-ml-px',
      extraClassName,
    ]),
    children: children,
  );
}

/// Static text addon placed inside a [buttonGroup].
BloomNode buttonGroupText({
  required String text,
  String extraClassName = '',
}) {
  return Span(
    className: cn([
      'inline-flex items-center px-3 text-sm font-medium border border-[var(--border)] '
          'bg-[var(--bg-muted)] text-[var(--text-muted)] rounded-[var(--radius-md)]',
      extraClassName,
    ]),
    text: text,
  );
}
