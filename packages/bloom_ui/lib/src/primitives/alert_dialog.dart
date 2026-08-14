// lib/src/primitives/alert_dialog.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

/// Modal dialog that interrupts the user with important content and expects a response.
/// Mirrors shadcn/ui AlertDialog (Base UI primitive).
class BloomAlertDialog extends StatelessWidget {
  final String title;
  final String description;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final Widget? media;

  const BloomAlertDialog({
    super.key,
    required this.title,
    required this.description,
    this.cancelText = 'Cancel',
    this.confirmText = 'Continue',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.media,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String description,
    String cancelText = 'Cancel',
    String confirmText = 'Continue',
    bool isDestructive = false,
    Widget? media,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BloomAlertDialog(
        title: title,
        description: description,
        cancelText: cancelText,
        confirmText: confirmText,
        isDestructive: isDestructive,
        media: media,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Dialog(
      backgroundColor: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: media!,
              ),
            ],
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BloomButton(
                  variant: BloomButtonVariant.outline,
                  onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                  child: Text(cancelText),
                ),
                const SizedBox(width: 8),
                BloomButton(
                  variant: isDestructive ? BloomButtonVariant.destructive : BloomButtonVariant.defaultVariant,
                  onPressed: onConfirm,
                  child: Text(confirmText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
