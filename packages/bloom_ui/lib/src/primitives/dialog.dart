// lib/src/primitives/dialog.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

class BloomDialog extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? content;
  final List<Widget>? actions;

  const BloomDialog({
    super.key,
    required this.title,
    this.description,
    this.content,
    this.actions,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? description,
    Widget? content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => BloomDialog(
        title: title,
        description: description,
        content: content,
        actions: actions,
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
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 16),
              content!,
            ],
            if (actions != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .map((a) => Padding(padding: const EdgeInsets.only(left: 8.0), child: a))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BloomAlertDialog extends StatelessWidget {
  final String title;
  final String description;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const BloomAlertDialog({
    super.key,
    required this.title,
    required this.description,
    this.cancelText = 'Cancel',
    this.confirmText = 'Continue',
    required this.onConfirm,
    this.isDestructive = false,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String description,
    String cancelText = 'Cancel',
    String confirmText = 'Continue',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BloomAlertDialog(
        title: title,
        description: description,
        cancelText: cancelText,
        confirmText: confirmText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BloomDialog(
      title: title,
      description: description,
      actions: [
        BloomButton(
          variant: BloomButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        BloomButton(
          variant: isDestructive ? BloomButtonVariant.destructive : BloomButtonVariant.defaultVariant,
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
