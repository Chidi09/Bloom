// lib/src/primitives/spinner.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// A circular loading spinner primitive matching shadcn/ui base-nova design specifications.
///
/// Draws a smooth, continuously rotating stroked arc without any Material dependency.
class BloomSpinner extends StatefulWidget {
  /// The diameter of the spinner in logical pixels.
  ///
  /// Defaults to `20.0`.
  final double size;

  /// The width of the circular progress stroke.
  ///
  /// Defaults to `2.5`.
  final double strokeWidth;

  /// The color of the spinner arc.
  ///
  /// Defaults to [BloomColorScheme.primary].
  final Color? color;

  /// The completion fraction, from 0.0 to 1.0.
  ///
  /// When null (the default) the spinner is indeterminate and rotates
  /// continuously. When non-null the arc is stationary and sweeps to that
  /// fraction of a full turn, so it reads as a progress ring.
  final double? value;

  /// Creates a [BloomSpinner].
  const BloomSpinner({
    super.key,
    this.size = 20.0,
    this.strokeWidth = 2.5,
    this.color,
    this.value,
  });

  @override
  State<BloomSpinner> createState() => _BloomSpinnerState();
}

class _BloomSpinnerState extends State<BloomSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(BloomSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.bloomColors.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _BloomSpinnerPainter(
              progress: _controller.value,
              value: widget.value,
              color: color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _BloomSpinnerPainter extends CustomPainter {
  final double progress;
  final double? value;
  final Color color;
  final double strokeWidth;

  const _BloomSpinnerPainter({
    required this.progress,
    this.value,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final double startAngle;
    final double sweepAngle;

    if (value == null) {
      startAngle = progress * 2 * math.pi;
      sweepAngle = 1.5 * math.pi * 0.75;
    } else {
      startAngle = -math.pi / 2;
      sweepAngle = value!.clamp(0.0, 1.0) * 2 * math.pi;
    }

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_BloomSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
