import '../framework.dart';
import 'cn.dart';

/// Horizontal or vertical divider primitive.
BloomNode separator({
  bool vertical = false,
  String extraClassName = '',
  Map<String, String> attrs = const {},
}) {
  return Div(
    attrs: {
      'role': 'separator',
      'aria-orientation': vertical ? 'vertical' : 'horizontal',
      ...attrs,
    },
    className: cn([
      'shrink-0 bg-[var(--border)]',
      vertical ? 'w-px h-full self-stretch' : 'h-px w-full',
      extraClassName,
    ]),
  );
}
