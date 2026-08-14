// lib/src/primitives/marker.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomMarkerVariant {
  defaultVariant,
  separator,
  border,
}

class BloomMarker extends StatelessWidget {
  final String text;
  final BloomMarkerVariant variant;
  final Widget? icon;

  const BloomMarker({
    super.key,
    required this.text,
    this.variant = BloomMarkerVariant.defaultVariant,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case BloomMarkerVariant.separator:
        return _buildSeparator(context);
      case BloomMarkerVariant.border:
        return _buildBorder(context);
      case BloomMarkerVariant.defaultVariant:
        return _buildDefault(context);
    }
  }

  Widget _buildDefault(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.secondary,
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: theme.typography.sans,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: theme.typography.sans,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }

  Widget _buildBorder(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: theme.typography.sans,
            ),
          ),
        ],
      ),
    );
  }
}
