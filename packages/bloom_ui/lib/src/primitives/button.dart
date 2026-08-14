// lib/src/primitives/button.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

enum BloomButtonVariant {
  defaultVariant,
  destructive,
  outline,
  secondary,
  ghost,
  link,
}

enum BloomButtonSize {
  defaultSize,
  sm,
  lg,
  icon,
}

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

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final colors = _resolveColors(context, variant);
    final dims = _resolveDimensions(size);

    final isInteractive = !loading && !disabled && onPressed != null;

    return Semantics(
      button: true,
      enabled: isInteractive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onPressed : null,
          borderRadius: BorderRadius.circular(theme.radius.md),
          child: AnimatedContainer(
            duration: BloomMotion.instant,
            height: dims.height,
            padding: dims.padding,
            decoration: BoxDecoration(
              color: isInteractive ? colors.background : colors.background.withValues(alpha: 0.5),
              border: colors.border != Colors.transparent ? Border.all(color: colors.border) : null,
              borderRadius: BorderRadius.circular(theme.radius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colors.foreground),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (leftIcon != null) ...[
                  leftIcon!,
                  const SizedBox(width: 8),
                ],
                DefaultTextStyle(
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: dims.fontSize,
                    fontFamily: theme.typography.sans,
                    fontWeight: FontWeight.w600,
                  ),
                  child: child,
                ),
                if (rightIcon != null && !loading) ...[
                  const SizedBox(width: 8),
                  rightIcon!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static _ButtonColors _resolveColors(BuildContext context, BloomButtonVariant variant) {
    final c = context.bloomColors;
    switch (variant) {
      case BloomButtonVariant.defaultVariant:
        return _ButtonColors(background: c.primary, foreground: c.primaryForeground, border: Colors.transparent);
      case BloomButtonVariant.destructive:
        return _ButtonColors(background: c.destructive, foreground: c.destructiveForeground, border: Colors.transparent);
      case BloomButtonVariant.outline:
        return _ButtonColors(background: Colors.transparent, foreground: c.textPrimary, border: c.border);
      case BloomButtonVariant.secondary:
        return _ButtonColors(background: c.secondary, foreground: c.secondaryForeground, border: Colors.transparent);
      case BloomButtonVariant.ghost:
        return _ButtonColors(background: Colors.transparent, foreground: c.textPrimary, border: Colors.transparent);
      case BloomButtonVariant.link:
        return _ButtonColors(background: Colors.transparent, foreground: c.primary, border: Colors.transparent);
    }
  }

  static _ButtonDimensions _resolveDimensions(BloomButtonSize size) {
    switch (size) {
      case BloomButtonSize.sm:
        return const _ButtonDimensions(height: 36, padding: EdgeInsets.symmetric(horizontal: 12), fontSize: 13);
      case BloomButtonSize.defaultSize:
        return const _ButtonDimensions(height: 42, padding: EdgeInsets.symmetric(horizontal: 16), fontSize: 14);
      case BloomButtonSize.lg:
        return const _ButtonDimensions(height: 48, padding: EdgeInsets.symmetric(horizontal: 24), fontSize: 16);
      case BloomButtonSize.icon:
        return const _ButtonDimensions(height: 42, padding: EdgeInsets.all(10), fontSize: 14);
    }
  }
}

class BloomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final BloomButtonVariant variant;
  final double size;
  final String? tooltip;

  const BloomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = BloomButtonVariant.ghost,
    this.size = 40,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: variant == BloomButtonVariant.outline ? Border.all(color: context.bloomColors.border) : null,
          ),
          child: icon,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _ButtonColors({required this.background, required this.foreground, required this.border});
}

class _ButtonDimensions {
  final double height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  const _ButtonDimensions({required this.height, required this.padding, required this.fontSize});
}
