// lib/src/primitives/button.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Button visual variants matching shadcn/ui base-nova.
enum BloomButtonVariant {
  defaultVariant,
  outline,
  secondary,
  ghost,
  destructive,
  link,
}

/// Button size options matching shadcn/ui base-nova height & padding scale.
enum BloomButtonSize {
  defaultSize, // h-8 (32px)
  xs,          // h-6 (24px)
  sm,          // h-7 (28px)
  lg,          // h-9 (36px)
  icon,        // 32x32px (size-8)
  iconXs,      // 24x24px (size-6)
  iconSm,      // 28x28px (size-7)
  iconLg,      // 36x36px (size-9)
}

/// Interactive button component matching shadcn/ui base-nova exactly.
class BloomButton extends StatelessWidget {
  final BloomButtonVariant variant;
  final BloomButtonSize size;
  final bool loading;
  final bool disabled;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final VoidCallback? onPressed;
  final Widget child;

  const BloomButton({
    super.key,
    this.variant = BloomButtonVariant.defaultVariant,
    this.size = BloomButtonSize.defaultSize,
    this.loading = false,
    this.disabled = false,
    this.leftIcon,
    this.rightIcon,
    required this.onPressed,
    required this.child,
  });

  /// Factory constructor for icon-only button
  factory BloomButton.icon({
    Key? key,
    required Widget icon,
    VoidCallback? onPressed,
    BloomButtonVariant variant = BloomButtonVariant.ghost,
    BloomButtonSize size = BloomButtonSize.icon,
    bool loading = false,
    bool disabled = false,
  }) {
    return BloomButton(
      key: key,
      variant: variant,
      size: size,
      loading: loading,
      disabled: disabled,
      onPressed: onPressed,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, variant);
    final dims = _resolveDimensions(size);

    final isInteractive = !loading && !disabled && onPressed != null;
    final isIconOnly = size == BloomButtonSize.icon ||
        size == BloomButtonSize.iconXs ||
        size == BloomButtonSize.iconSm ||
        size == BloomButtonSize.iconLg;

    final radius = _resolveRadius(context, size);

    return Semantics(
      button: true,
      enabled: isInteractive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onPressed : null,
          borderRadius: BorderRadius.circular(radius),
          splashColor: colors.foreground.withValues(alpha: 0.12),
          highlightColor: colors.foreground.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: BloomMotion.instant,
            curve: BloomMotion.easeOut,
            width: isIconOnly ? dims.height : null,
            height: dims.height,
            padding: dims.padding,
            decoration: BoxDecoration(
              color: isInteractive
                  ? colors.background
                  : colors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(radius),
              border: colors.border != Colors.transparent
                  ? Border.all(color: colors.border)
                  : null,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: isInteractive
                    ? colors.foreground
                    : colors.foreground.withValues(alpha: 0.5),
                size: dims.iconSize,
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: isInteractive
                      ? colors.foreground
                      : colors.foreground.withValues(alpha: 0.5),
                  fontSize: dims.fontSize,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                  letterSpacing: -0.1,
                  decoration: variant == BloomButtonVariant.link
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (loading) ...[
                      SizedBox(
                        width: dims.iconSize,
                        height: dims.iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.foreground,
                        ),
                      ),
                      if (!isIconOnly) SizedBox(width: dims.gap),
                    ] else if (leftIcon != null) ...[
                      leftIcon!,
                      SizedBox(width: dims.gap),
                    ],
                    if (!isIconOnly || (!loading && leftIcon == null && rightIcon == null))
                      child,
                    if (rightIcon != null && !loading) ...[
                      SizedBox(width: dims.gap),
                      rightIcon!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _resolveRadius(BuildContext context, BloomButtonSize size) {
    if (size == BloomButtonSize.xs || size == BloomButtonSize.iconXs) {
      return 6.0;
    }
    if (size == BloomButtonSize.sm || size == BloomButtonSize.iconSm) {
      return 7.0;
    }
    return 8.0; // rounded-lg
  }

  _ButtonColors _resolveColors(BuildContext context, BloomButtonVariant variant) {
    final colors = context.bloomColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case BloomButtonVariant.defaultVariant:
        return _ButtonColors(
          background: colors.primary,
          foreground: colors.primaryForeground,
          border: Colors.transparent,
        );
      case BloomButtonVariant.outline:
        return _ButtonColors(
          background: isDark
              ? colors.border.withValues(alpha: 0.2)
              : Colors.transparent,
          foreground: colors.textPrimary,
          border: colors.border,
        );
      case BloomButtonVariant.secondary:
        return _ButtonColors(
          background: colors.secondary,
          foreground: colors.secondaryForeground,
          border: Colors.transparent,
        );
      case BloomButtonVariant.ghost:
        return _ButtonColors(
          background: Colors.transparent,
          foreground: colors.textPrimary,
          border: Colors.transparent,
        );
      case BloomButtonVariant.destructive:
        // shadcn base-nova uses soft 10% tint for destructive button
        return _ButtonColors(
          background: colors.destructive.withValues(alpha: isDark ? 0.2 : 0.1),
          foreground: colors.destructive,
          border: isDark ? colors.destructive.withValues(alpha: 0.3) : Colors.transparent,
        );
      case BloomButtonVariant.link:
        return _ButtonColors(
          background: Colors.transparent,
          foreground: colors.primary,
          border: Colors.transparent,
        );
    }
  }

  _ButtonDimensions _resolveDimensions(BloomButtonSize size) {
    switch (size) {
      case BloomButtonSize.xs:
        return const _ButtonDimensions(
          height: 24,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          fontSize: 12,
          iconSize: 12,
          gap: 4,
        );
      case BloomButtonSize.sm:
        return const _ButtonDimensions(
          height: 28,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          fontSize: 12.8,
          iconSize: 14,
          gap: 4,
        );
      case BloomButtonSize.defaultSize:
        return const _ButtonDimensions(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          fontSize: 14,
          iconSize: 16,
          gap: 6,
        );
      case BloomButtonSize.lg:
        return const _ButtonDimensions(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          fontSize: 14,
          iconSize: 16,
          gap: 6,
        );
      case BloomButtonSize.iconXs:
        return const _ButtonDimensions(
          height: 24,
          padding: EdgeInsets.zero,
          fontSize: 12,
          iconSize: 12,
          gap: 0,
        );
      case BloomButtonSize.iconSm:
        return const _ButtonDimensions(
          height: 28,
          padding: EdgeInsets.zero,
          fontSize: 12.8,
          iconSize: 14,
          gap: 0,
        );
      case BloomButtonSize.icon:
        return const _ButtonDimensions(
          height: 32,
          padding: EdgeInsets.zero,
          fontSize: 14,
          iconSize: 16,
          gap: 0,
        );
      case BloomButtonSize.iconLg:
        return const _ButtonDimensions(
          height: 36,
          padding: EdgeInsets.zero,
          fontSize: 14,
          iconSize: 16,
          gap: 0,
        );
    }
  }
}

/// Icon button shorthand
class BloomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final BloomButtonVariant variant;
  final BloomButtonSize size;
  final String? tooltip;
  final bool disabled;
  final bool loading;

  const BloomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = BloomButtonVariant.ghost,
    this.size = BloomButtonSize.icon,
    this.tooltip,
    this.disabled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = BloomButton(
      variant: variant,
      size: size,
      disabled: disabled,
      loading: loading,
      onPressed: onPressed,
      child: icon,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

class _ButtonDimensions {
  final double height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;
  final double gap;

  const _ButtonDimensions({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
    required this.gap,
  });
}
