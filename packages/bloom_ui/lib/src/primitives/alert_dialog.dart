// lib/src/primitives/alert_dialog.dart
import 'package:flutter/widgets.dart';
import '../utils/bloom_modal_routes.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';
import 'button.dart';

/// Modal confirmation alert dialog matching shadcn/ui base-nova.
class BloomAlertDialog extends StatelessWidget {
  final Widget? media;
  final Widget? title;
  final Widget? description;
  final Widget? action;
  final Widget? cancel;
  final Widget? content;
  final double maxWidth;

  const BloomAlertDialog({
    super.key,
    this.media,
    this.title,
    this.description,
    this.action,
    this.cancel,
    this.content,
    this.maxWidth = 400,
  });

  /// Static helper to display alert confirmation modal
  static Future<bool?> show({
    required BuildContext context,
    Widget? media,
    required String title,
    required String description,
    String confirmLabel = 'Continue',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showBloomDialog<bool>(
      context: context,
      builder: (ctx) => BloomAlertDialog(
        media: media,
        title: Text(title),
        description: Text(description),
        cancel: BloomButton(
          variant: BloomButtonVariant.outline,
          size: BloomButtonSize.sm,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        action: BloomButton(
          variant: isDestructive ? BloomButtonVariant.destructive : BloomButtonVariant.defaultVariant,
          size: BloomButtonSize.sm,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final radius = context.bloomRadius.xl;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: BloomSurface(
            elevation: 8,
            borderRadius: BorderRadius.circular(radius),
            color: colors.surface1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (media != null) ...[
                        media!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null)
                              DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: context.bloomTypography.sans,
                                  color: colors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                child: title!,
                              ),
                            if (description != null) ...[
                              const SizedBox(height: 6),
                              DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: context.bloomTypography.sans,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                                child: description!,
                              ),
                            ],
                            if (content != null) ...[
                              const SizedBox(height: 12),
                              content!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface0.withValues(alpha: 0.5),
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cancel != null) cancel!,
                      if (cancel != null && action != null) const SizedBox(width: 8),
                      if (action != null) action!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

/// Icon box slot in AlertDialog
class BloomAlertDialogMedia extends StatelessWidget {
  final Widget icon;
  final Color? backgroundColor;

  const BloomAlertDialogMedia({
    super.key,
    required this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface0,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
