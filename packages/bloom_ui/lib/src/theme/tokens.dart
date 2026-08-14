// lib/src/theme/tokens.dart
import 'package:flutter/material.dart';

/// 5-Petal Brand Colors & Semantic Surfaces from the Bloom Design System.
class BloomColors {
  // Brand Petals
  static const Color petalPink = Color(0xFFFF4B8B);
  static const Color petalOrange = Color(0xFFFF884D);
  static const Color petalCyan = Color(0xFF20C9B0);
  static const Color petalBlue = Color(0xFF3B82F6);
  static const Color petalPurple = Color(0xFF8B5CF6);

  // Light Surfaces
  static const Color surface0Light = Color(0xFFFAFAFA);
  static const Color surface1Light = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xF2FFFFFF);
  static const Color borderSubtleLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // Dark Surfaces
  static const Color surface0Dark = Color(0xFF030509);
  static const Color surface1Dark = Color(0xFF0D1117);
  static const Color surface2Dark = Color(0xF20D1117);
  static const Color borderSubtleDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Semantic Status
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF3B82F6);
}

/// 4px Base Spacing Scale (4, 8, 12, 16, 24, 32, 48, 64)
class BloomSpacing {
  final double s1;
  final double s2;
  final double s3;
  final double s4;
  final double s5;
  final double s6;
  final double s7;
  final double s8;

  const BloomSpacing({
    this.s1 = 4,
    this.s2 = 8,
    this.s3 = 12,
    this.s4 = 16,
    this.s5 = 24,
    this.s6 = 32,
    this.s7 = 48,
    this.s8 = 64,
  });
}

/// Standardized Radius Scale (base = 10px -> sm=6, md=8, lg=10, xl=14, full=999)
class BloomRadius {
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  const BloomRadius({
    this.sm = 6,
    this.md = 8,
    this.lg = 10,
    this.xl = 14,
    this.full = 999,
  });
}

/// Typography Scale (Modular 1.25 ratio, base 16px)
class BloomTypography {
  final String sans;
  final String mono;
  final double xs;
  final double sm;
  final double base;
  final double lg;
  final double xl;
  final double xl2;
  final double xl3;
  final double xl4;

  const BloomTypography({
    this.sans = 'Geist',
    this.mono = 'GeistMono',
    this.xs = 12,
    this.sm = 14,
    this.base = 16,
    this.lg = 18,
    this.xl = 20,
    this.xl2 = 25,
    this.xl3 = 31,
    this.xl4 = 39,
  });
}

/// Elevation Shadow Scale
class BloomShadows {
  static const BoxShadow s1 = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  static const BoxShadow s2 = BoxShadow(
    color: Color(0x121F2687),
    blurRadius: 32,
    offset: Offset(0, 8),
  );

  static const BoxShadow s3 = BoxShadow(
    color: Color(0x268B5CF6),
    blurRadius: 40,
    offset: Offset(0, 12),
  );

  static const BoxShadow s4 = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 60,
    offset: Offset(0, 20),
  );
}

/// Motion Durations and Curves
class BloomMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 800);

  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);
  static const Curve easeSpring = Cubic(0.175, 0.885, 0.32, 1.275);
}
