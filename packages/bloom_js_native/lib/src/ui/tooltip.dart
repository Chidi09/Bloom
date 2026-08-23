import '../framework.dart';
import 'cn.dart';

/// Pure CSS tooltip component with hover and focus-within reveal triggers.
BloomNode tooltip({
  required String label,
  required BloomNode child,
  String side = 'top',
  String extraClassName = '',
}) {
  String positionClasses;
  switch (side) {
    case 'bottom':
      positionClasses = 'top-full left-1/2 -translate-x-1/2 mt-1.5';
      break;
    case 'left':
      positionClasses = 'right-full top-1/2 -translate-y-1/2 mr-1.5';
      break;
    case 'right':
      positionClasses = 'left-full top-1/2 -translate-y-1/2 ml-1.5';
      break;
    case 'top':
    default:
      positionClasses = 'bottom-full left-1/2 -translate-x-1/2 mb-1.5';
      break;
  }

  return Div(
    className: cn(['relative inline-flex group/tt', extraClassName]),
    children: [
      child,
      Span(
        attrs: const {'role': 'tooltip'},
        className: cn([
          'pointer-events-none absolute z-50 whitespace-nowrap px-2 py-1 rounded-[var(--radius-sm)] '
          'bg-[var(--n-900)] text-[var(--n-50)] text-xs font-medium opacity-0 '
          'group-hover/tt:opacity-100 group-focus-within/tt:opacity-100 transition-opacity duration-150 shadow-sm',
          positionClasses,
        ]),
        text: label,
      ),
    ],
  );
}
