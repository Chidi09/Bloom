/// Vector logo widget for the Bloom framework.
library;

import 'package:flutter/widgets.dart';

/// The real Bloom five-petal gradient flower mark, matching the brand SVG
/// used across bloom.dev and the Cloud dashboard (`bloom-logo.tsx`).
///
/// Renders via [CustomPainter] on a 200x200 design grid so it stays crisp at
/// any [size] without shipping an image asset or a new SVG dependency.
///
/// Example:
/// ```dart
/// const logo = BloomLogo(size: 48);
/// ```
class BloomLogo extends StatelessWidget {
  /// Creates a [BloomLogo] icon widget with the specified logical pixel [size].
  const BloomLogo({super.key, this.size = 40});

  /// Render size (width and height) in logical pixels.
  final double size;


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BloomLogoPainter()),
    );
  }
}

class _BloomLogoPainter extends CustomPainter {
  static final List<_Petal> _petals = [
    _Petal(
      path: 'M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z',
      from: const Offset(100, 20),
      to: const Offset(100, 100),
      colors: const [Color(0xFFFF4B8B), Color(0xFFFF8BA7)],
    ),
    _Petal(
      path: 'M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z',
      from: const Offset(180, 80),
      to: const Offset(110, 110),
      colors: const [Color(0xFFFF884D), Color(0xFFFFA066)],
    ),
    _Petal(
      path: 'M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z',
      from: const Offset(140, 175),
      to: const Offset(100, 115),
      colors: const [Color(0xFF20C9B0), Color(0xFF48E5C8)],
    ),
    _Petal(
      path: 'M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z',
      from: const Offset(60, 175),
      to: const Offset(100, 115),
      colors: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
    ),
    _Petal(
      path: 'M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z',
      from: const Offset(20, 80),
      to: const Offset(90, 110),
      colors: const [Color(0xFF8B5CF6), Color(0xFFA855F7)],
    ),
  ];

  static const String _sparkle =
      'M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z';

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    canvas.save();
    canvas.scale(scale, scale);

    for (final petal in _petals) {
      final path = _parseSvgPath(petal.path);
      final paint = Paint()
        ..shader = LinearGradient(colors: petal.colors).createShader(
          Rect.fromPoints(petal.from, petal.to),
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint..color = paint.color.withValues(alpha: 0.95));
    }

    canvas.drawPath(_parseSvgPath(_sparkle), Paint()..color = const Color(0xFFFFFFFF));
    canvas.restore();
  }

  /// Minimal M/C/L/Z parser sufficient for the fixed petal/sparkle paths above.
  Path _parseSvgPath(String d) {
    final path = Path();
    final tokens = d.trim().split(RegExp(r'\s+'));
    var i = 0;
    Offset current = Offset.zero;

    double nextNum() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final cmd = tokens[i++];
      switch (cmd) {
        case 'M':
          current = Offset(nextNum(), nextNum());
          path.moveTo(current.dx, current.dy);
          break;
        case 'L':
          current = Offset(nextNum(), nextNum());
          path.lineTo(current.dx, current.dy);
          break;
        case 'C':
          final c1 = Offset(nextNum(), nextNum());
          final c2 = Offset(nextNum(), nextNum());
          final end = Offset(nextNum(), nextNum());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          current = end;
          break;
        case 'Z':
          path.close();
          break;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _BloomLogoPainter oldDelegate) => false;
}

class _Petal {
  const _Petal({required this.path, required this.from, required this.to, required this.colors});

  final String path;
  final Offset from;
  final Offset to;
  final List<Color> colors;
}
