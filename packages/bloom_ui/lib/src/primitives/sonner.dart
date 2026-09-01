// lib/src/primitives/sonner.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/bloom_toast_host.dart';
import '../utils/extensions.dart';
import 'spinner.dart';

/// Semantic notification type for [BloomSonner] toasts.
enum BloomSonnerType {
  /// Standard neutral toast notification without an icon.
  normal,

  /// Success toast featuring a green checkmark icon.
  success,

  /// Error toast featuring a red error icon.
  error,

  /// Warning toast featuring an amber alert icon.
  warning,

  /// Informational toast featuring a blue info icon.
  info,

  /// Loading toast featuring an active circular progress indicator.
  loading,
}

/// An opinionated, modern toast notification system for Flutter applications.
///
/// Provides convenient static helpers for standard status toasts ([success], [error],
/// [warning], [info], [loading]) as well as rich customizable action callbacks.
///
/// Example:
/// ```dart
/// BloomSonner.success(
///   context,
///   'Deployment successful',
///   description: 'Version 2.4.0 is now live.',
///   actionLabel: 'View',
///   onAction: () => print('Viewing deployment'),
/// );
/// ```
class BloomSonner {
  /// Displays a floating [BloomSonner] toast with fully customizable parameters.
  ///
  /// * [context]: The build context containing the target overlay.
  /// * [message]: Main headline message text.
  /// * [description]: Optional secondary description text.
  /// * [type]: Semantic category determining the leading indicator icon (defaults to [BloomSonnerType.normal]).
  /// * [duration]: Visibility duration before automatic dismissal (defaults to 4 seconds).
  /// * [action]: Custom widget displayed on the right edge of the toast.
  /// * [actionLabel]: Label text for an action button on the right edge.
  /// * [onAction]: Tap callback triggered when [actionLabel] button is clicked.
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

    Widget? leadingIcon;
    switch (type) {
      case BloomSonnerType.success:
        leadingIcon = BloomIcon(BloomIcons.checkCircleOutline, color: colors.success, size: 18);
        break;
      case BloomSonnerType.error:
        leadingIcon = BloomIcon(BloomIcons.errorOutline, color: colors.error, size: 18);
        break;
      case BloomSonnerType.warning:
        leadingIcon = BloomIcon(BloomIcons.warning, color: colors.warning, size: 18);
        break;
      case BloomSonnerType.info:
        leadingIcon = BloomIcon(BloomIcons.infoOutline, color: colors.info, size: 18);
        break;
      case BloomSonnerType.loading:
        leadingIcon = BloomSpinner(
          size: 16,
          strokeWidth: 2,
          color: colors.primary,
        );
        break;
      case BloomSonnerType.normal:
        leadingIcon = null;
        break;
    }

    late final BloomToastHandle handle;
    handle = BloomToastHost.show(
      context,
      duration: duration,
      alignment: BloomToastAlignment.bottomCenter,
      child: BloomSurface(
        elevation: 6,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        color: colors.surface1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
                const SizedBox(width: 12),
              ],
              Flexible(
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
                BloomPressable(
                  onTap: () {
                    handle.dismiss();
                    onAction();
                  },
                  borderRadius: BorderRadius.circular(context.bloomRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Displays a success toast with a green checkmark icon.
  ///
  /// * [context]: The build context.
  /// * [message]: Main success message.
  /// * [description]: Optional secondary explanation.
  /// * [actionLabel]: Optional action button text.
  /// * [onAction]: Optional callback executed on action click.
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

  /// Displays an error toast with a red alert icon.
  ///
  /// * [context]: The build context.
  /// * [message]: Main error message.
  /// * [description]: Optional secondary error details.
  /// * [actionLabel]: Optional retry or action button text.
  /// * [onAction]: Optional callback executed on action click.
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

  /// Displays a warning toast with an amber alert icon.
  ///
  /// * [context]: The build context.
  /// * [message]: Main warning message.
  /// * [description]: Optional secondary details.
  /// * [actionLabel]: Optional action button text.
  /// * [onAction]: Optional callback executed on action click.
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

  /// Displays an informational toast with a blue info icon.
  ///
  /// * [context]: The build context.
  /// * [message]: Main info message.
  /// * [description]: Optional secondary details.
  /// * [actionLabel]: Optional action button text.
  /// * [onAction]: Optional callback executed on action click.
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

  /// Displays an ongoing loading toast with an active spinner indicator.
  ///
  /// * [context]: The build context.
  /// * [message]: Main loading status message.
  /// * [description]: Optional secondary details.
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

