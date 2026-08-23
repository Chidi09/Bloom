import '../framework.dart';
import 'cn.dart';

/// Pure CSS hover card preview component.
///
/// Reveals rich preview [content] on hover and focus-within.
BloomNode hoverCard({
  required BloomNode trigger,
  required BloomNode content,
  String side = 'bottom',
  String align = 'center',
  String extraClassName = '',
}) {
  String positionClasses;
  switch (side) {
    case 'top':
      final alignClass = align == 'left'
          ? 'left-0'
          : align == 'right'
              ? 'right-0'
              : 'left-1/2 -translate-x-1/2';
      positionClasses = 'bottom-full mb-2 $alignClass';
      break;
    case 'left':
      positionClasses = 'right-full top-1/2 -translate-y-1/2 mr-2';
      break;
    case 'right':
      positionClasses = 'left-full top-1/2 -translate-y-1/2 ml-2';
      break;
    case 'bottom':
    default:
      final alignClass = align == 'left'
          ? 'left-0'
          : align == 'right'
              ? 'right-0'
              : 'left-1/2 -translate-x-1/2';
      positionClasses = 'top-full mt-2 $alignClass';
      break;
  }

  return Div(
    attrs: const {'data-slot': 'hover-card'},
    className: cn(['relative inline-block group/hc', extraClassName]),
    children: [
      trigger,
      Div(
        attrs: const {'role': 'tooltip'},
        className: cn([
          'invisible opacity-0 group-hover/hc:visible group-hover/hc:opacity-100 '
          'group-focus-within/hc:visible group-focus-within/hc:opacity-100 '
          'transition-all duration-150 absolute z-50 min-w-[220px] max-w-xs '
          'rounded-[var(--radius-md)] border border-[var(--border)] '
          'bg-[var(--card)] text-[var(--card-foreground)] p-3 shadow-[var(--shadow-overlay)] text-xs',
          positionClasses,
        ]),
        children: [content],
      ),
    ],
  );
}
