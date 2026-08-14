// lib/src/primitives/sonner.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

enum BloomSonnerType { normal, success, error, warning, info, loading }

/// An opinionated, beautiful toast component for Flutter.
/// Mirrors shadcn/ui Sonner toaster primitive.
class BloomSonner {
  static void show(
    BuildContext context, {
    required String message,
    String? description,
    BloomSonnerType type = BloomSonnerType.normal,
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;
    final scaffold = ScaffoldMessenger.of(context);

    Widget? leadingIcon;
    switch (type) {
      case BloomSonnerType.success:
        leadingIcon = Icon(Icons.check_circle_outline, color: colors.success, size: 18);
        break;
      case BloomSonnerType.error:
        leadingIcon = Icon(Icons.error_outline, color: colors.error, size: 18);
        break;
      case BloomSonnerType.warning:
        leadingIcon = Icon(Icons.warning_amber_outlined, color: colors.warning, size: 18);
        break;
      case BloomSonnerType.info:
        leadingIcon = Icon(Icons.info_outline, color: colors.info, size: 18);
        break;
      case BloomSonnerType.loading:
        leadingIcon = SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colors.primary)),
        );
        break;
      case BloomSonnerType.normal:
        leadingIcon = null;
        break;
    }

    scaffold.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: Border.all(color: colors.border),
            boxShadow: const [BloomShadows.s3],
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: typography.sans,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontFamily: typography.sans,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action,
              ] else if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    scaffold.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: typography.sans,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      description: description,
      type: BloomSonnerType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      description: description,
      type: BloomSonnerType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      description: description,
      type: BloomSonnerType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      description: description,
      type: BloomSonnerType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void loading(
    BuildContext context,
    String message, {
    String? description,
  }) {
    show(
      context,
      message: message,
      description: description,
      type: BloomSonnerType.loading,
    );
  }
}
