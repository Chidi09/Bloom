// lib/src/icons/bloom_icon_data.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';

/// A single drawing primitive inside a [BloomIconData]'s 24x24 view box.
sealed class BloomIconShape {
  /// Base const constructor for icon shapes.
  const BloomIconShape();
}

/// A straight stroked segment from ([x1], [y1]) to ([x2], [y2]).
class BloomIconLine extends BloomIconShape {
  /// Creates a line segment between two points on the 24x24 grid.
  const BloomIconLine(this.x1, this.y1, this.x2, this.y2);

  /// Starting x-coordinate.
  final double x1;

  /// Starting y-coordinate.
  final double y1;

  /// Ending x-coordinate.
  final double x2;

  /// Ending y-coordinate.
  final double y2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconLine &&
          other.x1 == x1 &&
          other.y1 == y1 &&
          other.x2 == x2 &&
          other.y2 == y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);
}

/// A stroked polyline through flat [points] pairs: `[x0, y0, x1, y1, ...]`.
///
/// When [close] is true the final point connects back to the first.
class BloomIconPolyline extends BloomIconShape {
  /// Creates a polyline path on the 24x24 grid.
  const BloomIconPolyline(
    this.points, {
    this.close = false,
    this.filled = false,
  });

  /// Flat list of coordinate pairs: `[x0, y0, x1, y1, ...]`.
  final List<double> points;

  /// Whether the polyline forms a closed polygon connecting the last point to the first.
  final bool close;

  /// Whether the shape is filled rather than stroked.
  final bool filled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconPolyline &&
          other.close == close &&
          other.filled == filled &&
          listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(close, filled, Object.hashAll(points));
}

/// A circle centred at ([cx], [cy]) with radius [r]; stroked unless [filled].
class BloomIconCircle extends BloomIconShape {
  /// Creates a circle shape on the 24x24 grid.
  const BloomIconCircle(
    this.cx,
    this.cy,
    this.r, {
    this.filled = false,
  });

  /// Center x-coordinate.
  final double cx;

  /// Center y-coordinate.
  final double cy;

  /// Circle radius.
  final double r;

  /// Whether the circle is filled rather than stroked.
  final bool filled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconCircle &&
          other.cx == cx &&
          other.cy == cy &&
          other.r == r &&
          other.filled == filled;

  @override
  int get hashCode => Object.hash(cx, cy, r, filled);
}

/// A rounded rectangle; stroked unless [filled].
class BloomIconRect extends BloomIconShape {
  /// Creates a rectangle shape on the 24x24 grid with optional corner rounding.
  const BloomIconRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.radius = 0,
    this.filled = false,
  });

  /// Top-left x-coordinate.
  final double x;

  /// Top-left y-coordinate.
  final double y;

  /// Rectangle width.
  final double width;

  /// Rectangle height.
  final double height;

  /// Corner radius for rounded corners.
  final double radius;

  /// Whether the rectangle is filled rather than stroked.
  final bool filled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconRect &&
          other.x == x &&
          other.y == y &&
          other.width == width &&
          other.height == height &&
          other.radius == radius &&
          other.filled == filled;

  @override
  int get hashCode => Object.hash(x, y, width, height, radius, filled);
}

/// A stroked arc, angles in radians, 0 pointing right, positive clockwise.
class BloomIconArc extends BloomIconShape {
  /// Creates a circular arc on the 24x24 grid.
  const BloomIconArc(
    this.cx,
    this.cy,
    this.r,
    this.startAngle,
    this.sweepAngle,
  );

  /// Center x-coordinate of the circle defining the arc.
  final double cx;

  /// Center y-coordinate of the circle defining the arc.
  final double cy;

  /// Radius of the arc circle.
  final double r;

  /// Starting angle in radians (0 pointing right / 3 o'clock).
  final double startAngle;

  /// Sweep angle in radians, measured positive clockwise.
  final double sweepAngle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconArc &&
          other.cx == cx &&
          other.cy == cy &&
          other.r == r &&
          other.startAngle == startAngle &&
          other.sweepAngle == sweepAngle;

  @override
  int get hashCode => Object.hash(cx, cy, r, startAngle, sweepAngle);
}

/// A centred letterform, used by the text-formatting icons.
class BloomIconGlyph extends BloomIconShape {
  /// Creates a centered text glyph inside the 24x24 view box.
  const BloomIconGlyph(
    this.text, {
    this.weight = FontWeight.w600,
    this.italic = false,
    this.underline = false,
  });

  /// The character string to render.
  final String text;

  /// Typeface font weight.
  final FontWeight weight;

  /// Whether to render in italic font style.
  final bool italic;

  /// Whether to draw an underline beneath the glyph.
  final bool underline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomIconGlyph &&
          other.text == text &&
          other.weight == weight &&
          other.italic == italic &&
          other.underline == underline;

  @override
  int get hashCode => Object.hash(text, weight, italic, underline);
}

/// The description of one Bloom icon: a list of shapes on a 24x24 grid.
@immutable
class BloomIconData {
  /// Creates an icon descriptor with a collection of 24x24 shapes and an optional stroke width.
  const BloomIconData(
    this.shapes, {
    this.strokeWidth = 2.0,
  });

  /// The primitive geometric shapes comprising this icon in a 24x24 view box.
  final List<BloomIconShape> shapes;

  /// Stroke width in view-box units, scaled with the rendered size.
  final double strokeWidth;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BloomIconData &&
        other.strokeWidth == strokeWidth &&
        listEquals(other.shapes, shapes);
  }

  @override
  int get hashCode => Object.hash(strokeWidth, Object.hashAll(shapes));
}
