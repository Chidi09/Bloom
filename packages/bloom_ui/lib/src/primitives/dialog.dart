// lib/src/primitives/dialog.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Modal dialog container matching shadcn/ui base-nova dialog architecture.
class BloomDialog extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Widget? child;
  final double maxWidth;
  final bool showClose;
  final VoidCallback? onClose;

  const BloomDialog({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.maxWidth = 440,
    this.showClose = true,
    this.onClose,
  });

  /// Static helper to display modal dialog easily
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final radius = context.bloomRadius.xl;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.border),
            boxShadow: const [BloomShadows.s3],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null) header!,
                    if (content != null) content!,
                    if (child != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: child!,
                      ),
                    if (footer != null) footer!,
                  ],
                ),
                if (showClose)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: InkWell(
                      onTap: onClose ?? () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(context.bloomRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog header slot
class BloomDialogHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? child;

  const BloomDialogHeader({
    super.key,
    this.title,
    this.description,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: child ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) title!,
              if (description != null) ...[
                const SizedBox(height: 4),
                description!,
              ],
            ],
          ),
    );
  }
}

/// Dialog title
class BloomDialogTitle extends StatelessWidget {
  final String text;
  const BloomDialogTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Dialog subtitle description
class BloomDialogDescription extends StatelessWidget {
  final String text;
  const BloomDialogDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

/// Dialog body content slot
class BloomDialogContent extends StatelessWidget {
  final Widget child;
  const BloomDialogContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: child,
    );
  }
}

/// Styled footer slot for BloomDialog with shaded background and top border
class BloomDialogFooter extends StatelessWidget {
  final List<Widget> actions;
  final Widget? child;

  const BloomDialogFooter({super.key, this.actions = const [], this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface0.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.all(12),
      child: child ??
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions
                .map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a))
                .toList(),
          ),
    );
  }
}
