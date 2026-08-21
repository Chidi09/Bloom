// lib/src/primitives/toast.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// A lightweight floating toast notification utility.
///
/// Dispatches floating SnackBar-based toast messages with structured title, optional description,
/// leading icon, and surface container styling.
///
/// Example:
/// ```dart
/// BloomToast.show(
///   context,
///   title: 'Changes saved',
///   description: 'Your profile settings have been updated.',
///   icon: Icons.check_circle_outline,
///   duration: const Duration(seconds: 3),
/// );
/// ```
class BloomToast {
  /// Displays a floating toast notification.
  ///
  /// * [context]: Build context used to locate [ScaffoldMessenger].
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
    final scaffold = ScaffoldMessenger.of(context);

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
              if (icon != null) ...[
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
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

