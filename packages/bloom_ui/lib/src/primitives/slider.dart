// lib/src/primitives/slider.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// A styled range slider matching shadcn base-nova design specifications with a 4px track and custom thumb ring.
///
/// Provides a self-contained slider with themed styling tokens, rounded track shapes, and circular thumb shadow.
///
/// ```dart
/// BloomSlider(
///   value: volume,
///   min: 0.0,
///   max: 100.0,
///   divisions: 10,
///   onChanged: (val) => setState(() => volume = val),
/// )
/// ```
class BloomSlider extends StatelessWidget {
  /// The current value of the slider, clamped between [min] and [max].
  final double value;

  /// Callback invoked when the user drags the slider thumb to a new value.
  ///
  /// If `null` or if [disabled] is `true`, the slider will be non-interactive.
  final ValueChanged<double>? onChanged;

  /// The minimum selectable value on the track.
  ///
  /// Defaults to `0.0`.
  final double min;

  /// The maximum selectable value on the track.
  ///
  /// Defaults to `1.0`.
  final double max;

  /// The number of discrete subdivisions along the track.
  ///
  /// If `null`, the slider changes continuously.
  final int? divisions;

  /// Whether the slider is disabled and non-interactive.
  ///
  /// When `true`, user interactions are disabled.
  final bool disabled;

  /// Creates a [BloomSlider].
  const BloomSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.disabled = false,
  });

  void _updateValueFromPosition(double localDx, double totalWidth) {
    if (disabled || onChanged == null || max <= min) return;
    const thumbRadius = 7.0;
    final usableWidth = totalWidth - 2 * thumbRadius;
    if (usableWidth <= 0) return;

    double fraction = (localDx - thumbRadius) / usableWidth;
    fraction = fraction.clamp(0.0, 1.0);
    double newValue = min + fraction * (max - min);

    if (divisions != null && divisions! > 0) {
      final step = (max - min) / divisions!;
      newValue = (min + ((newValue - min) / step).round() * step).clamp(min, max);
    }
    onChanged!(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isInteractive = !disabled && onChanged != null && max > min;
    final clampedValue = value.clamp(min, max);

    final step = (divisions != null && divisions! > 0)
        ? (max - min) / divisions!
        : (max - min) / 20.0;
    final increasedValue = (clampedValue + step).clamp(min, max);
    final decreasedValue = (clampedValue - step).clamp(min, max);

    void increase() {
      if (isInteractive) {
        onChanged!(increasedValue);
      }
    }

    void decrease() {
      if (isInteractive) {
        onChanged!(decreasedValue);
      }
    }

    return Semantics(
      slider: true,
      enabled: isInteractive,
      value: clampedValue.toStringAsFixed(1),
      increasedValue: increasedValue.toStringAsFixed(1),
      decreasedValue: decreasedValue.toStringAsFixed(1),
      onIncrease: isInteractive ? increase : null,
      onDecrease: isInteractive ? decrease : null,
      child: Focus(
        canRequestFocus: isInteractive,
        onKeyEvent: (node, event) {
          if (!isInteractive || event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            increase();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            decrease();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final isFinite = totalWidth.isFinite && totalWidth > 0;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: isInteractive && isFinite
                  ? (details) => _updateValueFromPosition(details.localPosition.dx, totalWidth)
                  : null,
              onTapDown: isInteractive && isFinite
                  ? (details) => _updateValueFromPosition(details.localPosition.dx, totalWidth)
                  : null,
              child: SizedBox(
                height: 32.0,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BloomSliderPainter(
                    value: clampedValue,
                    min: min,
                    max: max,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surface0,
                    thumbColor: colors.surface1,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BloomSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color thumbColor;

  const _BloomSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.activeTrackColor,
    required this.inactiveTrackColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 4.0;
    const thumbRadius = 7.0;
    final trackTop = (size.height - trackHeight) / 2.0;

    final usableWidth = size.width - 2 * thumbRadius;
    final fraction = (max > min && usableWidth > 0)
        ? ((value - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;
    final thumbX = thumbRadius + fraction * (usableWidth > 0 ? usableWidth : 0.0);
    final thumbY = size.height / 2.0;

    // Inactive track
    final inactiveTrackRect = Rect.fromLTWH(0, trackTop, size.width, trackHeight);
    final inactiveRRect = RRect.fromRectAndRadius(
      inactiveTrackRect,
      const Radius.circular(trackHeight / 2),
    );
    final inactivePaint = Paint()
      ..color = inactiveTrackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(inactiveRRect, inactivePaint);

    // Active track
    if (thumbX > 0) {
      final activeTrackRect = Rect.fromLTWH(0, trackTop, thumbX, trackHeight);
      final activeRRect = RRect.fromRectAndRadius(
        activeTrackRect,
        const Radius.circular(trackHeight / 2),
      );
      final activePaint = Paint()
        ..color = activeTrackColor
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.clipRRect(inactiveRRect);
      canvas.drawRRect(activeRRect, activePaint);
      canvas.restore();
    }

    // Outer ring shadow
    final shadowPaint = Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(thumbX, thumbY + 1), thumbRadius, shadowPaint);

    // Inner thumb body
    final fillPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbRadius, fillPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = activeTrackColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbRadius, borderPaint);
  }

  @override
  bool shouldRepaint(_BloomSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.activeTrackColor != activeTrackColor ||
        oldDelegate.inactiveTrackColor != inactiveTrackColor ||
        oldDelegate.thumbColor != thumbColor;
  }
}
