// lib/src/primitives/badge.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
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

enum BloomBadgeSize {
  defaultSize, // h-5 (20px)
  sm,          // h-4 (16px)
  lg,          // h-6 (24px)
}

/// Status and label badge pill matching shadcn base-nova exactly.
class BloomBadge extends StatelessWidget {
  final BloomBadgeVariant variant;
  final BloomBadgeSize size;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget child;

  const BloomBadge({
    super.key,
    this.variant = BloomBadgeVariant.defaultVariant,
    this.size = BloomBadgeSize.defaultSize,
    this.leading,
    this.trailing,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, variant);
    final dims = _resolveDimensions(size);

    final badge = AnimatedContainer(
      duration: BloomMotion.instant,
      height: dims.height,
      padding: dims.padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999), // rounded-4xl
        border: colors.border != Colors.transparent
            ? Border.all(color: colors.border)
            : null,
      ),
      child: IconTheme(
        data: IconThemeData(color: colors.foreground, size: dims.iconSize),
        child: DefaultTextStyle(
          style: TextStyle(
            color: colors.foreground,
            fontSize: dims.fontSize,
            fontWeight: FontWeight.w500,
            fontFamily: context.bloomTypography.sans,
            letterSpacing: -0.1,
            decoration: variant == BloomBadgeVariant.link
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: dims.gap),
              ],
              child,
              if (trailing != null) ...[
                SizedBox(width: dims.gap),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: badge,
      );
    }

    return badge;
  }

  _BadgeColors _resolveColors(BuildContext context, BloomBadgeVariant variant) {
    final colors = context.bloomColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case BloomBadgeVariant.defaultVariant:
        return _BadgeColors(
          background: colors.primary,
          foreground: colors.primaryForeground,
          border: Colors.transparent,
        );
      case BloomBadgeVariant.secondary:
        return _BadgeColors(
          background: colors.secondary,
          foreground: colors.secondaryForeground,
          border: Colors.transparent,
        );
      case BloomBadgeVariant.destructive:
        // Soft tint in shadcn base-nova
        return _BadgeColors(
          background: colors.destructive.withValues(alpha: isDark ? 0.2 : 0.1),
          foreground: colors.destructive,
          border: isDark ? colors.destructive.withValues(alpha: 0.3) : Colors.transparent,
        );
      case BloomBadgeVariant.outline:
        return _BadgeColors(
          background: Colors.transparent,
          foreground: colors.textPrimary,
          border: colors.border,
        );
      case BloomBadgeVariant.ghost:
        return _BadgeColors(
          background: Colors.transparent,
          foreground: colors.textPrimary,
          border: Colors.transparent,
        );
      case BloomBadgeVariant.link:
        return _BadgeColors(
          background: Colors.transparent,
          foreground: colors.primary,
          border: Colors.transparent,
        );
      case BloomBadgeVariant.success:
        return _BadgeColors(
          background: colors.success.withValues(alpha: isDark ? 0.2 : 0.1),
          foreground: colors.success,
          border: Colors.transparent,
        );
    }
  }

  _BadgeDimensions _resolveDimensions(BloomBadgeSize size) {
    switch (size) {
      case BloomBadgeSize.sm:
        return const _BadgeDimensions(
          height: 16,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          fontSize: 10.5,
          iconSize: 10,
          gap: 3,
        );
      case BloomBadgeSize.defaultSize:
        return const _BadgeDimensions(
          height: 20,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          fontSize: 12,
          iconSize: 12,
          gap: 4,
        );
      case BloomBadgeSize.lg:
        return const _BadgeDimensions(
          height: 24,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          fontSize: 13,
          iconSize: 14,
          gap: 5,
        );
    }
  }
}

/// Removable tag/chip component
class BloomChip extends StatelessWidget {
  final Widget label;
  final Widget? avatar;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final BloomBadgeVariant variant;

  const BloomChip({
    super.key,
    required this.label,
    this.avatar,
    this.onDeleted,
    this.onTap,
    this.variant = BloomBadgeVariant.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return BloomBadge(
      variant: variant,
      size: BloomBadgeSize.defaultSize,
      leading: avatar,
      onTap: onTap,
      trailing: onDeleted != null
          ? GestureDetector(
              onTap: onDeleted,
              child: const Icon(Icons.close, size: 12),
            )
          : null,
      child: label,
    );
  }
}

class _BadgeColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

class _BadgeDimensions {
  final double height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;
  final double gap;
  const _BadgeDimensions({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
    required this.gap,
  });
}
