import '../framework.dart';
import 'cn.dart';

/// Aspect ratio container component primitive.
///
/// Constrains its child to a fixed aspect ratio (e.g. 16/9, 4/3, 1/1).
BloomNode aspectRatio({
  required double ratio,
  required BloomNode child,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {'data-slot': 'aspect-ratio'},
    style: 'aspect-ratio: $ratio; position: relative; width: 100%;',
    className: cn(['overflow-hidden', extraClassName]),
    children: [child],
  );
}
