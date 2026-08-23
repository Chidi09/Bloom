import '../framework.dart';
import 'cn.dart';

/// Scroll area component with customized lightweight scrollbars.
///
/// Implemented via pure CSS scroll styling without virtual-DOM overhead or heavy JS dependencies.
BloomNode scrollArea({
  required BloomNode child,
  double? maxHeight,
  double? maxWidth,
  String orientation = 'vertical',
  String extraClassName = '',
}) {
  final isVertical = orientation == 'vertical';
  final isHorizontal = orientation == 'horizontal';

  final overflowClass = isVertical
      ? 'overflow-y-auto overflow-x-hidden'
      : isHorizontal
          ? 'overflow-x-auto overflow-y-hidden'
          : 'overflow-auto';

  final styleBuffer = StringBuffer();
  if (maxHeight != null) styleBuffer.write('max-height: ${maxHeight}px; ');
  if (maxWidth != null) styleBuffer.write('max-width: ${maxWidth}px; ');
  final style = styleBuffer.isNotEmpty ? styleBuffer.toString().trim() : null;

  return Div(
    attrs: const {'data-slot': 'scroll-area'},
    style: style,
    className: cn([
      'relative w-full [scrollbar-width:thin] [scrollbar-color:var(--border)_transparent]',
      overflowClass,
      extraClassName,
    ]),
    children: [child],
  );
}
