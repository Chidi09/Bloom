// lib/src/primitives/drawer.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// A gesture-driven swipeable drawer bottom sheet component.
///
/// Designed to emulate bottom sheet drawer patterns with an optional grab handle,
/// rounded top borders, theme background tokens, and smooth drag-to-dismiss behavior.
///
/// Example:
/// ```dart
/// BloomDrawer.show(
///   context: context,
///   builder: (context) => BloomDrawer(
///     showHandle: true,
///     header: Padding(
///       padding: EdgeInsets.all(16),
///       child: Text('Drawer Title', style: TextStyle(fontWeight: FontWeight.bold)),
///     ),
///     content: Padding(
///       padding: EdgeInsets.symmetric(horizontal: 16),
///       child: Text('Drawer body content goes here.'),
///     ),
///   ),
/// );
/// ```
class BloomDrawer extends StatelessWidget {
  /// Optional header section placed below the drag handle.
  final Widget? header;

  /// Main content body widget.
  final Widget? content;

  /// Optional footer widget placed at the bottom of the drawer.
  final Widget? footer;

  /// Single child widget alternative with standard 16px padding.
  final Widget? child;

  /// Whether to render a centered drag indicator bar at the top of the drawer.
  final bool showHandle;

  /// Creates a [BloomDrawer].
  ///
  /// * [showHandle] controls the visibility of the grab handle pill (defaults to `true`).
  /// * [header], [content], [footer], or [child] supply the drawer's content.
  const BloomDrawer({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.showHandle = true,
  });

  /// Displays a modal swipeable drawer bottom sheet.
  ///
  /// * [context]: The build context for the modal sheet.
  /// * [builder]: Returns the drawer widget tree.
  /// * [isDismissible]: Whether tapping the barrier dismisses the drawer.
  /// * [enableDrag]: Whether the sheet can be dismissed by dragging down.
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

