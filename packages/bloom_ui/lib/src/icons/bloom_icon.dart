// lib/src/icons/bloom_icon.dart
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/extensions.dart';
import 'bloom_icon_data.dart';

/// Draws a [BloomIconData] with no Material dependency.
///
/// Honours the ambient [IconTheme] for size, color and opacity exactly as the core
/// [Icon] widget does.
class BloomIcon extends StatelessWidget {
  /// Creates a Bloom icon widget displaying [icon].
  const BloomIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth,
    this.semanticLabel,
    this.textDirection,
  });

  /// The icon data to display.
  ///
  /// If null, the widget renders as an empty square of [size].
  final BloomIconData? icon;

  /// The size of the icon in logical pixels (width and height).
  ///
  /// Defaults to ambient [IconThemeData.size] or 24.0.
  final double? size;

  /// The color to use when drawing the icon strokes, fills, and glyphs.
  ///
  /// Defaults to ambient [IconThemeData.color] or `context.bloomColors.textPrimary`.
  final Color? color;

  /// Optional override for the stroke width in view-box coordinates.
  ///
  /// Defaults to [BloomIconData.strokeWidth].
  final double? strokeWidth;

  /// Semantic label for accessibility and screen readers.
  final String? semanticLabel;

  /// Text direction used for layout and glyph alignment.
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final double resolvedSize = size ?? iconTheme.size ?? 24.0;
    Color resolvedColor = color ?? iconTheme.color ?? context.bloomColors.textPrimary;

    final double? iconOpacity = iconTheme.opacity;
    if (iconOpacity != null && iconOpacity != 1.0) {
      resolvedColor = resolvedColor.withValues(alpha: resolvedColor.a * iconOpacity);
    }

    final BloomIconData? iconData = icon;
    if (iconData == null) {
      final emptyBox = SizedBox.square(dimension: resolvedSize);
      if (semanticLabel != null) {
        return Semantics(
          label: semanticLabel,
          child: emptyBox,
        );
      }
      return emptyBox;
    }

    final TextDirection resolvedTextDirection =
        textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

    Widget iconWidget = SizedBox.square(
      dimension: resolvedSize,
      child: CustomPaint(
        painter: _BloomIconPainter(
          icon: iconData,
          color: resolvedColor,
          strokeWidth: strokeWidth,
          fontFamily: context.bloomTypography.sans,
          textDirection: resolvedTextDirection,
        ),
      ),
    );

    if (semanticLabel != null) {
      iconWidget = Semantics(
        label: semanticLabel,
        child: ExcludeSemantics(child: iconWidget),
      );
    }

    return iconWidget;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<BloomIconData>('icon', icon, ifNull: '<empty>', showName: false),
    );
    properties.add(DoubleProperty('size', size, defaultValue: null));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DoubleProperty('strokeWidth', strokeWidth, defaultValue: null));
    properties.add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
  }
}

class _BloomIconPainter extends CustomPainter {
  const _BloomIconPainter({
    required this.icon,
    required this.color,
    this.strokeWidth,
    required this.fontFamily,
    required this.textDirection,
  });

  final BloomIconData icon;
  final Color color;
  final double? strokeWidth;
  final String fontFamily;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth ?? icon.strokeWidth
      ..isAntiAlias = true
      ..color = color;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color;

    for (final shape in icon.shapes) {
      switch (shape) {
        case BloomIconLine line:
          canvas.drawLine(
            Offset(line.x1, line.y1),
            Offset(line.x2, line.y2),
            strokePaint,
          );
        case BloomIconPolyline polyline:
          final points = polyline.points;
          if (points.length >= 2) {
            final path = Path()..moveTo(points[0], points[1]);
            for (int i = 2; i < points.length; i += 2) {
              path.lineTo(points[i], points[i + 1]);
            }
            if (polyline.close) {
              path.close();
            }
            if (polyline.filled) {
              canvas.drawPath(path, fillPaint);
            } else {
              canvas.drawPath(path, strokePaint);
            }
          }
        case BloomIconCircle circle:
          if (circle.filled) {
            canvas.drawCircle(Offset(circle.cx, circle.cy), circle.r, fillPaint);
          } else {
            canvas.drawCircle(Offset(circle.cx, circle.cy), circle.r, strokePaint);
          }
        case BloomIconRect rect:
          if (rect.radius > 0) {
            final rrect = RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
              Radius.circular(rect.radius),
            );
            if (rect.filled) {
              canvas.drawRRect(rrect, fillPaint);
            } else {
              canvas.drawRRect(rrect, strokePaint);
            }
          } else {
            final r = Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height);
            if (rect.filled) {
              canvas.drawRect(r, fillPaint);
            } else {
              canvas.drawRect(r, strokePaint);
            }
          }
        case BloomIconArc arc:
          final oval = Rect.fromCircle(
            center: Offset(arc.cx, arc.cy),
            radius: arc.r,
          );
          canvas.drawArc(oval, arc.startAngle, arc.sweepAngle, false, strokePaint);
        case BloomIconGlyph glyph:
          final textPainter = TextPainter(
            text: TextSpan(
              text: glyph.text,
              style: TextStyle(
                color: color,
                fontSize: 16.0,
                fontFamily: fontFamily,
                fontWeight: glyph.weight,
                fontStyle: glyph.italic ? FontStyle.italic : FontStyle.normal,
                decoration: glyph.underline ? TextDecoration.underline : TextDecoration.none,
                decorationColor: color,
                height: 1.0,
              ),
            ),
            textDirection: textDirection,
          )..layout();

          final glyphOffset = Offset(
            (24.0 - textPainter.width) / 2.0,
            (24.0 - textPainter.height) / 2.0,
          );
          textPainter.paint(canvas, glyphOffset);
          textPainter.dispose();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BloomIconPainter oldDelegate) {
    return oldDelegate.icon != icon ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.textDirection != textDirection;
  }
}
