import '../framework.dart';
import 'cn.dart';

/// Determinate linear progress bar primitive.
BloomNode progress({
  required double value,
  double max = 100.0,
  String? label,
  bool showValue = false,
  String extraClassName = '',
}) {
  final pct = max > 0 ? (value / max * 100.0).clamp(0.0, 100.0) : 0.0;
  final pctStr = pct.toStringAsFixed(0);

  return Div(
    attrs: {
      'role': 'progressbar',
      'aria-valuenow': '$value',
      'aria-valuemin': '0',
      'aria-valuemax': '$max',
    },
    className: cn(['flex flex-col gap-1.5 w-full', extraClassName]),
    children: [
      if (label != null || showValue)
        Div(
          className: 'flex items-center justify-between text-xs font-medium text-[var(--text-muted)]',
          children: [
            if (label != null) Span(text: label),
            if (showValue) Span(className: 'ml-auto tabular', text: '$pctStr%'),
          ],
        ),
      Div(
        className: 'relative h-2 w-full overflow-hidden rounded-full bg-[var(--muted)]',
        children: [
          Div(
            className:
                'h-full bg-[var(--primary)] rounded-full transition-all duration-300',
            style: 'width: $pct%;',
          ),
        ],
      ),
    ],
  );
}
