// lib/src/primitives/typography.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomTypographyBlock extends StatelessWidget {
  final String text;
  final BloomTypographyVariant variant;

  const BloomTypographyBlock({super.key, required this.text, this.variant = BloomTypographyVariant.body});

  @override
  Widget build(BuildContext context) {
    final t = context.bloomTypography;
    final colors = context.bloomColors;
    return switch (variant) {
      BloomTypographyVariant.h1 => Text(text, style: TextStyle(fontSize: t.xl4, fontWeight: FontWeight.w700, color: colors.textPrimary, fontFamily: t.sans, height: 1.2)),
      BloomTypographyVariant.h2 => Text(text, style: TextStyle(fontSize: t.xl3, fontWeight: FontWeight.w600, color: colors.textPrimary, fontFamily: t.sans, height: 1.25)),
      BloomTypographyVariant.h3 => Text(text, style: TextStyle(fontSize: t.xl2, fontWeight: FontWeight.w600, color: colors.textPrimary, fontFamily: t.sans, height: 1.3)),
      BloomTypographyVariant.h4 => Text(text, style: TextStyle(fontSize: t.xl, fontWeight: FontWeight.w600, color: colors.textPrimary, fontFamily: t.sans, height: 1.35)),
      BloomTypographyVariant.body => Text(text, style: TextStyle(fontSize: t.base, fontWeight: FontWeight.w400, color: colors.textPrimary, fontFamily: t.sans, height: 1.5)),
      BloomTypographyVariant.small => Text(text, style: TextStyle(fontSize: t.sm, fontWeight: FontWeight.w400, color: colors.textSecondary, fontFamily: t.sans, height: 1.4)),
      BloomTypographyVariant.muted => Text(text, style: TextStyle(fontSize: t.sm, fontWeight: FontWeight.w400, color: colors.textTertiary, fontFamily: t.sans, height: 1.4)),
      BloomTypographyVariant.lead => Text(text, style: TextStyle(fontSize: t.lg, fontWeight: FontWeight.w400, color: colors.textPrimary, fontFamily: t.sans, height: 1.5)),
      BloomTypographyVariant.large => Text(text, style: TextStyle(fontSize: t.xl, fontWeight: FontWeight.w600, color: colors.textPrimary, fontFamily: t.sans, height: 1.4)),
      BloomTypographyVariant.mono => Text(text, style: TextStyle(fontSize: t.sm, fontWeight: FontWeight.w400, color: colors.textPrimary, fontFamily: t.mono, height: 1.4)),
    };
  }
}

enum BloomTypographyVariant { h1, h2, h3, h4, body, small, muted, lead, large, mono }
