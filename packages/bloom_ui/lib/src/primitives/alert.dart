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

/// Alert notification banner matching shadcn/ui base-nova.
class BloomAlert extends StatelessWidget {
  final BloomAlertVariant variant;
  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final Widget? action;
  final Widget? child;

  const BloomAlert({
    super.key,
    this.variant = BloomAlertVariant.defaultVariant,
    this.icon,
    this.title,
    this.description,
    this.action,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, variant);
    final theme = context.bloomTheme;

    Widget defaultIcon;
    switch (variant) {
      case BloomAlertVariant.defaultVariant:
        defaultIcon = const Icon(Icons.info_outline, size: 16);
        break;
      case BloomAlertVariant.destructive:
        defaultIcon = const Icon(Icons.error_outline, size: 16);
        break;
      case BloomAlertVariant.success:
        defaultIcon = const Icon(Icons.check_circle_outline, size: 16);
        break;
      case BloomAlertVariant.warning:
        defaultIcon = const Icon(Icons.warning_amber_rounded, size: 16);
        break;
      case BloomAlertVariant.info:
        defaultIcon = const Icon(Icons.info_outline, size: 16);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: IconThemeData(color: colors.foreground, size: 16),
            child: icon ?? defaultIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      DefaultTextStyle(
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: theme.typography.sans,
                          letterSpacing: -0.1,
                        ),
                        child: title!,
                      ),
                    if (description != null) ...[
                      if (title != null) const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: TextStyle(
                          color: variant == BloomAlertVariant.destructive
                              ? colors.foreground.withValues(alpha: 0.9)
                              : context.bloomColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: theme.typography.sans,
                          height: 1.4,
                        ),
                        child: description!,
                      ),
                    ],
                  ],
                ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }

  _AlertColors _resolveColors(BuildContext context, BloomAlertVariant variant) {
    final colors = context.bloomColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case BloomAlertVariant.defaultVariant:
        return _AlertColors(
          background: colors.surface1,
          foreground: colors.textPrimary,
          border: colors.border,
        );
      case BloomAlertVariant.destructive:
        return _AlertColors(
          background: colors.destructive.withValues(alpha: isDark ? 0.2 : 0.08),
          foreground: colors.destructive,
          border: colors.destructive.withValues(alpha: isDark ? 0.35 : 0.2),
        );
      case BloomAlertVariant.success:
        return _AlertColors(
          background: colors.success.withValues(alpha: isDark ? 0.2 : 0.08),
          foreground: colors.success,
          border: colors.success.withValues(alpha: isDark ? 0.35 : 0.2),
        );
      case BloomAlertVariant.warning:
        return _AlertColors(
          background: colors.warning.withValues(alpha: isDark ? 0.2 : 0.08),
          foreground: colors.warning,
          border: colors.warning.withValues(alpha: isDark ? 0.35 : 0.2),
        );
      case BloomAlertVariant.info:
        return _AlertColors(
          background: colors.info.withValues(alpha: isDark ? 0.2 : 0.08),
          foreground: colors.info,
          border: colors.info.withValues(alpha: isDark ? 0.35 : 0.2),
        );
    }
  }
}

class BloomAlertTitle extends StatelessWidget {
  final String text;
  const BloomAlertTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}

class BloomAlertDescription extends StatelessWidget {
  final String text;
  const BloomAlertDescription(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}

class BloomAlertAction extends StatelessWidget {
  final Widget child;
  const BloomAlertAction({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class _AlertColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _AlertColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
