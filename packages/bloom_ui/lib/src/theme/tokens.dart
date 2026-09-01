// lib/src/theme/tokens.dart
import 'package:flutter/widgets.dart';

/// 5-Petal Brand Colors and Semantic Surface tokens from the Bloom Design System.
///
/// Contains static constants for brand petal hues, light/dark surface layers,
/// text colors, subtle borders, and semantic status colors.
///
/// ## Usage
/// ```dart
/// Container(
///   color: BloomColors.surface1Light,
///   child: Text('Bloom UI', style: TextStyle(color: BloomColors.textPrimaryLight)),
/// );
/// ```
class BloomColors {
  // Base Colors

  /// Fully transparent color. Replaces Material's `Colors.transparent`.
  static const Color transparent = Color(0x00000000);

  /// Opaque white. Replaces Material's `Colors.white`.
  static const Color white = Color(0xFFFFFFFF);

  /// Opaque black. Replaces Material's `Colors.black`.
  static const Color black = Color(0xFF000000);

  // Brand Petals

  /// Vibrant pink petal brand accent (`#FFFF4B8B`).
  static const Color petalPink = Color(0xFFFF4B8B);

  /// Warm orange petal brand accent (`#FFFF884D`).
  static const Color petalOrange = Color(0xFFFF884D);

  /// Teal/cyan petal brand accent (`#FF20C9B0`).
  static const Color petalCyan = Color(0xFF20C9B0);

  /// Vibrant blue petal brand accent (`#FF3B82F6`).
  static const Color petalBlue = Color(0xFF3B82F6);

  /// Deep purple petal brand accent (`#FF8B5CF6`).
  static const Color petalPurple = Color(0xFF8B5CF6);

  // Light Surfaces

  /// Light theme background surface level 0 (`#FFFAFAFA`).
  static const Color surface0Light = Color(0xFFFAFAFA);

  /// Light theme elevated card/dialog surface level 1 (`#FFFFFFFF`).
  static const Color surface1Light = Color(0xFFFFFFFF);

  /// Light theme translucent overlay surface level 2 (`#F2FFFFFF`).
  static const Color surface2Light = Color(0xF2FFFFFF);

  /// Subtle light-mode divider and container border color (`#FFE2E8F0`).
  static const Color borderSubtleLight = Color(0xFFE2E8F0);

  /// Primary high-contrast light-mode body text color (`#FF0F172A`).
  static const Color textPrimaryLight = Color(0xFF0F172A);

  /// Secondary muted light-mode text color (`#FF475569`).
  static const Color textSecondaryLight = Color(0xFF475569);

  /// Tertiary placeholder and disabled light-mode text color (`#FF94A3B8`).
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // Dark Surfaces

  /// Dark theme deepest background surface level 0 (`#FF030509`).
  static const Color surface0Dark = Color(0xFF030509);

  /// Dark theme elevated card/dialog surface level 1 (`#FF0D1117`).
  static const Color surface1Dark = Color(0xFF0D1117);

  /// Dark theme translucent overlay surface level 2 (`#F20D1117`).
  static const Color surface2Dark = Color(0xF20D1117);

  /// Subtle dark-mode divider and container border color (`#FF334155`).
  static const Color borderSubtleDark = Color(0xFF334155);

  /// Primary high-contrast dark-mode body text color (`#FFF8FAFC`).
  static const Color textPrimaryDark = Color(0xFFF8FAFC);

  /// Secondary muted dark-mode text color (`#FF94A3B8`).
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  /// Tertiary placeholder and disabled dark-mode text color (`#FF64748B`).
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Semantic Status

  /// Standard success status green (`#FF059669`).
  static const Color success = Color(0xFF059669);

  /// Standard warning status amber (`#FFD97706`).
  static const Color warning = Color(0xFFD97706);

  /// Standard error/destructive status red (`#FFDC2626`).
  static const Color error = Color(0xFFDC2626);

  /// Standard informational status blue (`#FF3B82F6`).
  static const Color info = Color(0xFF3B82F6);
}

/// 4px-base spacing scale (4, 8, 12, 16, 24, 32, 48, 64) utilized across layout and component padding.
///
/// Spacing tokens can be customized per theme preset (e.g. compact vs generous modes).
///
/// ## Usage
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(context.bloomSpacing.s4),
///   child: child,
/// );
/// ```
class BloomSpacing {
  /// Extra small 4px spacing unit (step 1).
  final double s1;

  /// Small 8px spacing unit (step 2).
  final double s2;

  /// Compact 12px spacing unit (step 3).
  final double s3;

  /// Standard base 16px spacing unit (step 4).
  final double s4;

  /// Medium-large 24px spacing unit (step 5).
  final double s5;

  /// Large 32px spacing unit (step 6).
  final double s6;

  /// Extra large 48px spacing unit (step 7).
  final double s7;

  /// 2X Extra large 64px spacing unit (step 8).
  final double s8;

  /// Creates a [BloomSpacing] token configuration with standard 4px-base defaults.
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

/// Standardized corner radius scale for buttons, cards, dialogs, and inputs.
///
/// Base radii scale from sharp corners (0px) to full pill rounding (999px).
///
/// ## Usage
/// ```dart
/// BorderRadius.circular(context.bloomRadius.md);
/// ```
class BloomRadius {
  /// Small border radius (default: 6px), typically used for badges and small tags.
  final double sm;

  /// Medium border radius (default: 8px), typically used for buttons and text fields.
  final double md;

  /// Large border radius (default: 10px), typically used for cards and popovers.
  final double lg;

  /// Extra-large border radius (default: 14px), typically used for modals and sheets.
  final double xl;

  /// Fully rounded pill radius (default: 999px), used for pills, avatars, and circular badges.
  final double full;

  /// Creates a [BloomRadius] configuration with default step values.
  const BloomRadius({
    this.sm = 6,
    this.md = 8,
    this.lg = 10,
    this.xl = 14,
    this.full = 999,
  });
}

/// Modular typography scale (1.25 ratio, base 16px) and font family configuration.
///
/// Defines font families for sans and monospace typefaces along with type sizes.
///
/// ## Usage
/// ```dart
/// Text(
///   'Headline',
///   style: TextStyle(
///     fontFamily: context.bloomTypography.sans,
///     fontSize: context.bloomTypography.xl,
///   ),
/// );
/// ```
class BloomTypography {
  /// Primary sans-serif font family (default: 'Geist').
  final String sans;

  /// Monospace font family for code, keys, and technical data (default: 'GeistMono').
  final String mono;

  /// Extra small text size: 12px.
  final double xs;

  /// Small text size: 14px.
  final double sm;

  /// Base body text size: 16px.
  final double base;

  /// Large text size: 18px.
  final double lg;

  /// Extra large text size: 20px.
  final double xl;

  /// 2X Extra large heading size: 25px.
  final double xl2;

  /// 3X Extra large heading size: 31px.
  final double xl3;

  /// 4X Extra large display size: 39px.
  final double xl4;

  /// Creates a [BloomTypography] token definition with standard modular scale defaults.
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

/// Elevation box shadow scale providing 4 levels of depth and ambient glow.
///
/// ## Usage
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: const [BloomShadows.s2],
///   ),
/// );
/// ```
class BloomShadows {
  /// Level 1 subtle shadow for low-elevation cards, inputs, and small popups.
  static const BoxShadow s1 = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  /// Level 2 elevation shadow for floating menus, dropdowns, and cards.
  static const BoxShadow s2 = BoxShadow(
    color: Color(0x121F2687),
    blurRadius: 32,
    offset: Offset(0, 8),
  );

  /// Level 3 elevation shadow for popovers, modals, and spotlight components.
  static const BoxShadow s3 = BoxShadow(
    color: Color(0x268B5CF6),
    blurRadius: 40,
    offset: Offset(0, 12),
  );

  /// Level 4 high-elevation shadow for drawers, full overlays, and floating hero panels.
  static const BoxShadow s4 = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 60,
    offset: Offset(0, 20),
  );
}

/// Standardized animation durations and transition curves for Bloom UI.
///
/// ## Usage
/// ```dart
/// AnimatedContainer(
///   duration: BloomMotion.fast,
///   curve: BloomMotion.easeOut,
///   child: child,
/// );
/// ```
class BloomMotion {
  /// Ultra-fast micro-interaction duration (120ms), used for hover, tap, and toggle feedback.
  static const Duration instant = Duration(milliseconds: 120);

  /// Fast transition duration (200ms), used for dropdowns, tooltips, and small collapses.
  static const Duration fast = Duration(milliseconds: 200);

  /// Standard base transition duration (400ms), used for modal entries, tabs, and page transitions.
  static const Duration base = Duration(milliseconds: 400);

  /// Slow cinematic transition duration (800ms), used for large drawer reveals and hero animations.
  static const Duration slow = Duration(milliseconds: 800);

  /// Smooth cubic ease-out curve (`Cubic(0.16, 1, 0.3, 1)`).
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);

  /// Spring-like bouncy cubic curve (`Cubic(0.175, 0.885, 0.32, 1.275)`).
  static const Curve easeSpring = Cubic(0.175, 0.885, 0.32, 1.275);
}

