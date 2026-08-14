// lib/src/primitives/sheet.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

enum BloomSheetSide { left, right, top, bottom }

/// Multi-directional slide-over sheet overlay matching shadcn base-nova.
class BloomSheet extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Widget? child;
  final BloomSheetSide side;
  final bool showClose;
  final VoidCallback? onClose;

  const BloomSheet({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.side = BloomSheetSide.right,
    this.showClose = true,
    this.onClose,
  });

  /// Static helper to display a directional sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    BloomSheetSide side = BloomSheetSide.right,
  }) {
    if (side == BloomSheetSide.bottom) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: builder,
      );
    }

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sheet',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      pageBuilder: (ctx, _, __) => builder(ctx),
      transitionBuilder: (ctx, anim, _, page) {
        Offset begin;
        switch (side) {
          case BloomSheetSide.left:
            begin = const Offset(-1, 0);
            break;
          case BloomSheetSide.right:
            begin = const Offset(1, 0);
            break;
          case BloomSheetSide.top:
            begin = const Offset(0, -1);
            break;
          case BloomSheetSide.bottom:
            begin = const Offset(0, 1);
            break;
        }
        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: BloomMotion.easeOut),
          ),
          child: Align(
            alignment: side == BloomSheetSide.left
                ? Alignment.centerLeft
                : side == BloomSheetSide.right
                    ? Alignment.centerRight
                    : side == BloomSheetSide.top
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
            child: page,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isHoriz = side == BloomSheetSide.left || side == BloomSheetSide.right;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: isHoriz ? 380 : double.infinity,
        height: isHoriz ? double.infinity : 380,
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(
            left: side == BloomSheetSide.right ? BorderSide(color: colors.border) : BorderSide.none,
            right: side == BloomSheetSide.left ? BorderSide(color: colors.border) : BorderSide.none,
            top: side == BloomSheetSide.bottom ? BorderSide(color: colors.border) : BorderSide.none,
            bottom: side == BloomSheetSide.top ? BorderSide(color: colors.border) : BorderSide.none,
          ),
          boxShadow: const [BloomShadows.s3],
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) header!,
                  if (content != null) Expanded(child: content!),
                  if (child != null) Expanded(child: child!),
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
                      child: Icon(Icons.close, size: 16, color: colors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BloomSheetHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? child;

  const BloomSheetHeader({super.key, this.title, this.description, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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

class BloomSheetTitle extends StatelessWidget {
  final String text;
  const BloomSheetTitle(this.text, {super.key});

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

class BloomSheetDescription extends StatelessWidget {
  final String text;
  const BloomSheetDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

class BloomSheetFooter extends StatelessWidget {
  final Widget child;
  const BloomSheetFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bloomColors.surface0.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: context.bloomColors.border)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
