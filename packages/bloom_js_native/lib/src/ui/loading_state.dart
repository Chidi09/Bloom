import '../framework.dart';
import 'cn.dart';
import 'skeleton.dart';
import 'spinner.dart';

/// Standardized loading placeholder supporting spinner or skeleton rows.
BloomNode loadingState({
  String label = 'Loading...',
  bool useSkeleton = false,
  int skeletonRows = 3,
  String extraClassName = '',
}) {
  if (useSkeleton) {
    return Div(
      attrs: {
        'role': 'status',
        'aria-label': label,
      },
      className: cn(['w-full space-y-2.5 p-4', extraClassName]),
      children: [
        for (var i = 0; i < skeletonRows; i++)
          skeleton(
            extraClassName: i == skeletonRows - 1 ? 'h-4 w-2/3' : 'h-4 w-full',
          ),
      ],
    );
  }

  return Div(
    attrs: {
      'role': 'status',
      'aria-label': label,
    },
    className: cn([
      'flex flex-col items-center justify-center gap-3 p-8 text-center',
      extraClassName,
    ]),
    children: [
      spinner(size: SpinnerSize.md, label: label),
      P(className: 'text-sm text-[var(--text-muted)]', text: label),
    ],
  );
}
