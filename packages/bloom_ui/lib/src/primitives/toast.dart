// lib/src/primitives/toast.dart
import 'package:flutter/widgets.dart';
import '../utils/bloom_surface.dart';
import '../utils/bloom_toast_host.dart';
import '../utils/extensions.dart';

/// A lightweight floating toast notification utility.
///
/// Dispatches floating toast messages hosted in the overlay with structured title, optional description,
/// leading icon, and surface container styling.
///
/// Example:
/// ```dart
/// BloomToast.show(
///   context,
///   title: 'Changes saved',
///   description: 'Your profile settings have been updated.',
///   duration: const Duration(seconds: 3),
/// );
/// ```
class BloomToast {
  /// Displays a floating toast notification.
  ///
  /// * [context]: Build context used to locate the ambient overlay.
  /// * [title]: Primary headline message.
  /// * [description]: Optional secondary message details.
  /// * [icon]: Optional leading icon displayed next to the text.
  /// * [duration]: How long the toast remains visible (defaults to 4 seconds).
  static void show(
    BuildContext context, {
    required String title,
    String? description,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    final colors = context.bloomColors;

    BloomToastHost.show(
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
              if (icon != null) ...[
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontFamily: context.bloomTypography.sans,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


