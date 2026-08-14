// lib/src/primitives/slider.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Styled range slider matching shadcn base-nova 4px track and white ring thumb.
class BloomSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool disabled;

  const BloomSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4.0, // h-1 (4px)
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surface0, // bg-muted
        thumbColor: colors.surface1, // white thumb
        overlayColor: colors.primary.withValues(alpha: 0.12),
        thumbShape: const _BloomThumbShape(),
        trackShape: const _BloomTrackShape(),
      ),
      child: Slider(
        value: value.clamp(min, max),
        onChanged: disabled ? null : onChanged,
        min: min,
        max: max,
        divisions: divisions,
      ),
    );
  }
}

class _BloomTrackShape extends RoundedRectSliderTrackShape {
  const _BloomTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class _BloomThumbShape extends RoundSliderThumbShape {
  const _BloomThumbShape() : super(enabledThumbRadius: 7.0, elevation: 1.5);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    TextDirection textDirection = TextDirection.ltr,
    double value = 0.0,
    double textScaleFactor = 1.0,
    Size sizeWithOverflow = Size.zero,
  }) {
    final canvas = context.canvas;

    // Outer ring shadow
    final shadowPaint = Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(0, 1), 7.0, shadowPaint);

    // Inner thumb body
    final fillPaint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7.0, fillPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? const Color(0xFF171717)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 7.0, borderPaint);
  }
}
