import '../framework.dart';
import 'cn.dart';

/// Skeleton placeholder primitive with pulse loading animation.
BloomNode skeleton({
  String extraClassName = '',
  String? style,
}) {
  return Div(
    style: style,
    className: cn([
      'animate-pulse rounded-[var(--radius-sm)] bg-[var(--muted)]',
      extraClassName,
    ]),
  );
}
