// lib/src/primitives/drawer.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Swipeable gesture drawer with handle matching shadcn/vaul.
class BloomDrawer extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Widget? child;
  final bool showHandle;

  const BloomDrawer({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.showHandle = true,
  });

  /// Static helper to display swipeable drawer bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final radius = context.bloomRadius.xl;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: const [BloomShadows.s3],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            if (header != null) header!,
            if (content != null) content!,
            if (child != null) Padding(padding: const EdgeInsets.all(16), child: child!),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
