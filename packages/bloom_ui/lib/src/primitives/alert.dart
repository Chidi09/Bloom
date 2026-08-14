// lib/src/primitives/alert.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomAlertVariant {
  defaultVariant,
  destructive,
  success,
  warning,
  info,
}

class BloomAlert extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? icon;
  final BloomAlertVariant variant;

  const BloomAlert({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.variant = BloomAlertVariant.defaultVariant,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final style = _resolveStyle(context, variant);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            IconTheme(data: IconThemeData(color: style.iconColor, size: 20), child: icon!),
            const SizedBox(width: 12),
          ] else ...[
            Icon(style.defaultIcon, color: style.iconColor, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: context.bloomTypography.sans,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _AlertStyle _resolveStyle(BuildContext context, BloomAlertVariant variant) {
    final c = context.bloomColors;
    switch (variant) {
      case BloomAlertVariant.defaultVariant:
        return _AlertStyle(
          background: c.surface2,
          border: c.border,
          iconColor: c.textPrimary,
          defaultIcon: Icons.info_outline,
        );
      case BloomAlertVariant.destructive:
        return _AlertStyle(
          background: c.error.withValues(alpha: 0.08),
          border: c.error.withValues(alpha: 0.3),
          iconColor: c.error,
          defaultIcon: Icons.error_outline,
        );
      case BloomAlertVariant.success:
        return _AlertStyle(
          background: c.success.withValues(alpha: 0.08),
          border: c.success.withValues(alpha: 0.3),
          iconColor: c.success,
          defaultIcon: Icons.check_circle_outline,
        );
      case BloomAlertVariant.warning:
        return _AlertStyle(
          background: c.warning.withValues(alpha: 0.08),
          border: c.warning.withValues(alpha: 0.3),
          iconColor: c.warning,
          defaultIcon: Icons.warning_amber_outlined,
        );
      case BloomAlertVariant.info:
        return _AlertStyle(
          background: c.info.withValues(alpha: 0.08),
          border: c.info.withValues(alpha: 0.3),
          iconColor: c.info,
          defaultIcon: Icons.info_outline,
        );
    }
  }
}

class _AlertStyle {
  final Color background;
  final Color border;
  final Color iconColor;
  final IconData defaultIcon;

  const _AlertStyle({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.defaultIcon,
  });
}
