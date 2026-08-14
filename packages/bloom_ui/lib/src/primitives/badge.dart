// lib/src/primitives/badge.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomBadgeVariant {
  defaultVariant,
  secondary,
  destructive,
  outline,
  ghost,
  link,
  success,
}

class BloomBadge extends StatelessWidget {
  final Widget child;
  final BloomBadgeVariant variant;
  final VoidCallback? onTap;

  const BloomBadge({
    super.key,
    required this.child,
    this.variant = BloomBadgeVariant.defaultVariant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context, variant);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: style.border != Colors.transparent ? Border.all(color: style.border) : null,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: style.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: badge);
    }
    return badge;
  }

  static _BadgeStyle _resolveStyle(BuildContext context, BloomBadgeVariant variant) {
    final c = context.bloomColors;
    switch (variant) {
      case BloomBadgeVariant.defaultVariant:
        return _BadgeStyle(background: c.primary, foreground: c.primaryForeground, border: Colors.transparent);
      case BloomBadgeVariant.secondary:
        return _BadgeStyle(background: c.secondary, foreground: c.secondaryForeground, border: Colors.transparent);
      case BloomBadgeVariant.outline:
        return _BadgeStyle(background: Colors.transparent, foreground: c.textPrimary, border: c.border);
      case BloomBadgeVariant.ghost:
        return _BadgeStyle(background: Colors.transparent, foreground: c.textPrimary, border: Colors.transparent);
      case BloomBadgeVariant.link:
        return _BadgeStyle(background: Colors.transparent, foreground: c.primary, border: Colors.transparent);
      case BloomBadgeVariant.destructive:
        return _BadgeStyle(background: c.destructive, foreground: c.destructiveForeground, border: Colors.transparent);
      case BloomBadgeVariant.success:
        return _BadgeStyle(background: c.success, foreground: Colors.white, border: Colors.transparent);
    }
  }
}

class BloomChip extends StatelessWidget {
  final String label;
  final Widget? avatar;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool selected;

  const BloomChip({
    super.key,
    required this.label,
    this.avatar,
    this.onDeleted,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface2,
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.primaryForeground : colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: selected ? colors.primaryForeground : colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeStyle {
  final Color background;
  final Color foreground;
  final Color border;
  const _BadgeStyle({required this.background, required this.foreground, required this.border});
}
