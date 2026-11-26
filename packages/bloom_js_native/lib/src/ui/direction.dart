import '../framework.dart';
import 'cn.dart';

/// Text directionality for [direction].
enum UiTextDirection {
  /// Left-to-right text layout.
  ltr,

  /// Right-to-left text layout.
  rtl,
}

/// Sets the HTML `dir` attribute (`ltr` or `rtl`) for its [children] subtree.
BloomNode direction({
  required UiTextDirection dir,
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  final dirValue = dir == UiTextDirection.rtl ? 'rtl' : 'ltr';
  return Div(
    attrs: {'dir': dirValue},
    className: cn(['w-full', extraClassName]),
    children: children,
  );
}
