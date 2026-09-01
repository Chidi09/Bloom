// lib/src/primitives/sheet.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/bloom_modal_routes.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';

export '../utils/bloom_modal_routes.dart' show BloomSheetSide;

/// A multi-directional slide-over sheet overlay component.
///
/// Sheets extend from any edge of the viewport (left, right, top, bottom) to display
/// supplementary content, forms, navigation drawers, or detailed inspection panels.
///
/// Example:
/// ```dart
/// BloomSheet.show(
///   context: context,
///   side: BloomSheetSide.right,
///   builder: (context) => BloomSheet(
///     side: BloomSheetSide.right,
///     header: BloomSheetHeader(
///       title: BloomSheetTitle('Edit Profile'),
///       description: BloomSheetDescription('Update your profile settings here.'),
///     ),
///     content: Center(child: Text('Profile form content')),
///     footer: BloomSheetFooter(
///       child: BloomPressable(
///         onTap: () => Navigator.of(context).pop(),
///         child: const Text('Save Changes'),
///       ),
///     ),
///   ),
/// );
/// ```
class BloomSheet extends StatelessWidget {
  /// Optional header section placed at the top of the sheet.
  final Widget? header;

  /// Main content widget occupying the expandable body area.
  final Widget? content;

  /// Optional footer section placed at the bottom of the sheet.
  final Widget? footer;

  /// Alternative single child widget spanning the body area.
  final Widget? child;

  /// The edge of the viewport from which the sheet originates.
  final BloomSheetSide side;

  /// Whether to show a close icon button in the top-right corner.
  final bool showClose;

  /// Callback triggered when the close icon button is tapped.
  /// Defaults to popping the current navigator route.
  final VoidCallback? onClose;

  /// Creates a [BloomSheet] overlay.
  ///
  /// * [side] defines the viewport edge where the sheet is positioned.
  /// * [showClose] determines whether the top-right dismiss button is visible.
  /// * [header], [content], [footer], and [child] structure the internal layout.
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

  /// Displays a [BloomSheet] modal overlay sliding in from the specified [side].
  ///
  /// * [context]: The build context to mount the modal into.
  /// * [builder]: Builder returning the sheet widget tree.
  /// * [side]: Viewport origin side (defaults to [BloomSheetSide.right]).
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    BloomSheetSide side = BloomSheetSide.right,
  }) {
    return showBloomSheet<T>(
      context: context,
      builder: builder,
      side: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isHoriz = side == BloomSheetSide.left || side == BloomSheetSide.right;

    return BloomSurface(
      elevation: 8,
      color: colors.surface1,
      child: Container(
        width: isHoriz ? 380 : double.infinity,
        height: isHoriz ? double.infinity : 380,
        decoration: BoxDecoration(
          border: Border(
            left: side == BloomSheetSide.right ? BorderSide(color: colors.border) : BorderSide.none,
            right: side == BloomSheetSide.left ? BorderSide(color: colors.border) : BorderSide.none,
            top: side == BloomSheetSide.bottom ? BorderSide(color: colors.border) : BorderSide.none,
            bottom: side == BloomSheetSide.top ? BorderSide(color: colors.border) : BorderSide.none,
          ),
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
                  child: BloomPressable(
                    onTap: onClose ?? () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(context.bloomRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: BloomIcon(BloomIcons.close, size: 16, color: colors.textSecondary),
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

/// A standardized header container for [BloomSheet].
///
/// Formats title and description widgets with appropriate spacing and alignment.
class BloomSheetHeader extends StatelessWidget {
  /// Header title widget, typically a [BloomSheetTitle].
  final Widget? title;

  /// Header description widget, typically a [BloomSheetDescription].
  final Widget? description;

  /// Custom child widget that completely overrides title and description rendering.
  final Widget? child;

  /// Creates a [BloomSheetHeader].
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

/// A standardized title text component for [BloomSheetHeader].
class BloomSheetTitle extends StatelessWidget {
  /// The title text string.
  final String text;

  /// Creates a [BloomSheetTitle] with the given [text].
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

/// A standardized secondary description text component for [BloomSheetHeader].
class BloomSheetDescription extends StatelessWidget {
  /// The description text string.
  final String text;

  /// Creates a [BloomSheetDescription] with the given [text].
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

/// A standardized bottom footer container for [BloomSheet].
///
/// Features a subtle top border and subdued background styling suitable for action buttons.
class BloomSheetFooter extends StatelessWidget {
  /// Content to display inside the footer, typically action buttons.
  final Widget child;

  /// Creates a [BloomSheetFooter] wrapping the provided [child].
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
