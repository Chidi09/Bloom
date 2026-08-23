import 'dart:math' as math;
import '../framework.dart';
import 'cn.dart';

/// Circular determinate progress indicator primitive.
///
/// Pure SVG implementation with smooth stroke animations.
BloomNode circularProgress({
  required double value,
  double max = 100,
  double size = 40,
  double strokeWidth = 3.5,
  String? color,
  String? label,
  bool showValue = false,
  String extraClassName = '',
}) {
  final clampedMax = max <= 0 ? 100.0 : max;
  final clampedValue = value.clamp(0.0, clampedMax);
  final percentage = (clampedValue / clampedMax).clamp(0.0, 1.0);

  final radius = (size - strokeWidth) / 2.0;
  final circumference = 2 * math.pi * radius;
  final strokeDashoffset = circumference - (percentage * circumference);

  final progressColor = color ?? 'var(--primary)';
  final center = size / 2.0;

  return Div(
    attrs: {
      'role': 'progressbar',
      'aria-valuenow': '$clampedValue',
      'aria-valuemin': '0',
      'aria-valuemax': '$clampedMax',
      'data-slot': 'circular-progress',
    },
    className: cn(['inline-flex flex-col items-center gap-1.5 select-none', extraClassName]),
    children: [
      Div(
        className: 'relative inline-flex items-center justify-center',
        children: [
          El(
            'svg',
            attrs: {
              'width': '$size',
              'height': '$size',
              'viewBox': '0 0 $size $size',
              'aria-hidden': 'true',
            },
            className: 'shrink-0 -rotate-90',
            children: [
              // Background track
              El(
                'circle',
                attrs: {
                  'cx': '$center',
                  'cy': '$center',
                  'r': '$radius',
                  'fill': 'none',
                  'stroke': 'var(--muted)',
                  'stroke-width': '$strokeWidth',
                },
              ),
              // Animated progress arc
              El(
                'circle',
                attrs: {
                  'cx': '$center',
                  'cy': '$center',
                  'r': '$radius',
                  'fill': 'none',
                  'stroke': progressColor,
                  'stroke-width': '$strokeWidth',
                  'stroke-dasharray': '$circumference',
                  'stroke-dashoffset': '$strokeDashoffset',
                  'stroke-linecap': 'round',
                },
                className: 'transition-all duration-300 ease-out',
              ),
            ],
          ),
          if (showValue)
            Span(
              className: 'absolute text-[10px] font-semibold text-[var(--text)]',
              text: '${(percentage * 100).round()}%',
            ),
        ],
      ),
      if (label != null && label.isNotEmpty)
        Span(
          className: 'text-xs text-[var(--text-muted)]',
          text: label,
        ),
    ],
  );
}
