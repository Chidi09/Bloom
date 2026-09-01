// lib/src/primitives/dropdown_menu.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';

/// An individual action or item displayed within a [BloomDropdownMenu] or [BloomContextMenu].
class BloomDropdownMenuItem {
  /// The descriptive title text of the menu item.
  final String label;

  /// Optional leading icon widget.
  final Widget? icon;

  /// Optional trailing keyboard shortcut label or accessory widget.
  final Widget? shortcut;

  /// Callback executed when this menu item is selected.
  final VoidCallback? onTap;

  /// Whether this item represents a destructive action (rendered in error/destructive color).
  final bool isDestructive;

  /// Whether this item is disabled and non-interactive.
  final bool disabled;

  /// Creates a [BloomDropdownMenuItem].
  ///
  /// * [label]: Display text of the item.
  /// * [icon]: Leading icon widget.
  /// * [shortcut]: Trailing accessory or shortcut indicator widget.
  /// * [onTap]: Tap action callback.
  /// * [isDestructive]: Renders item with destructive token styling if `true`.
  /// * [disabled]: Disables interaction and dims styling if `true`.
  const BloomDropdownMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isDestructive = false,
    this.disabled = false,
  });
}

/// A contextual dropdown menu popup component anchored to a trigger widget.
///
/// Wraps a [RawMenuAnchor] with Bloom tokens for styling, rounded corners,
/// elevation shadows, typography, and support for keyboard shortcuts and destructive items.
///
/// Example:
/// ```dart
/// BloomDropdownMenu(
///   trigger: BloomPressable(
///     child: const Text('Options'),
///   ),
///   items: [
///     BloomDropdownMenuItem(
///       label: 'Edit',
///       icon: BloomIcon(BloomIcons.edit),
///       onTap: () => print('Edit tapped'),
///     ),
///     BloomDropdownMenuItem(
///       label: 'Delete',
///       icon: BloomIcon(BloomIcons.deleteOutline),
///       isDestructive: true,
///       onTap: () => print('Delete tapped'),
///     ),
///   ],
/// );
/// ```
class BloomDropdownMenu extends StatefulWidget {
  /// The anchor trigger widget that displays the menu upon interaction.
  final Widget trigger;

  /// The list of items displayed inside the dropdown menu.
  final List<BloomDropdownMenuItem> items;

  /// Width constraint of the dropdown popup menu. Defaults to `200`.
  final double width;

  /// Creates a [BloomDropdownMenu].
  ///
  /// * [trigger]: The widget that opens the popup when clicked.
  /// * [items]: List of menu item entries.
  /// * [width]: Width in logical pixels (defaults to `200`).
  const BloomDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
    this.width = 200,
  });

  @override
  State<BloomDropdownMenu> createState() => _BloomDropdownMenuState();
}

class _BloomDropdownMenuState extends State<BloomDropdownMenu> {
  final MenuController _controller = MenuController();

  Widget _buildItem(BuildContext context, BloomDropdownMenuItem item) {
    final colors = context.bloomColors;
    final textCol = item.isDestructive
        ? colors.destructive
        : item.disabled
            ? colors.textTertiary
            : colors.textPrimary;

    return BloomPressable(
      enabled: !item.disabled,
      onTap: () {
        _controller.close();
        item.onTap?.call();
      },
      borderRadius: BorderRadius.circular(context.bloomRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            if (item.icon != null) ...[
              IconTheme(
                data: IconThemeData(color: textCol, size: 16),
                child: item.icon!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: textCol,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ),
            if (item.shortcut != null) item.shortcut!,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final radius = context.bloomRadius;

    return RawMenuAnchor(
      controller: _controller,
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return BloomPressable(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: widget.trigger,
        );
      },
      overlayBuilder: (BuildContext context, RawMenuOverlayInfo info) {
        double left = info.anchorRect.left;
        double top = info.anchorRect.bottom + 6;

        if (left + widget.width > info.overlaySize.width) {
          left = math.max(0.0, info.overlaySize.width - widget.width - 8);
        }
        if (top + (widget.items.length * 36) > info.overlaySize.height) {
          top = math.max(0.0, info.anchorRect.top - (widget.items.length * 36) - 6);
        }

        return TapRegion(
          groupId: info.tapRegionGroupId,
          onTapOutside: (PointerDownEvent event) {
            _controller.close();
          },
          child: CustomSingleChildLayout(
            delegate: _BloomMenuLayoutDelegate(position: Offset(left, top)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.width,
                maxWidth: widget.width,
              ),
              child: BloomSurface(
                elevation: 8,
                borderRadius: BorderRadius.circular(radius.md),
                color: colors.surface1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius.md),
                    border: Border.all(color: colors.border),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in widget.items)
                        _buildItem(context, item),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BloomMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset position;

  const _BloomMenuLayoutDelegate({required this.position});

  @override
  Offset getPositionForChild(Size size, Size childSize) => position;

  @override
  bool shouldRelayout(covariant _BloomMenuLayoutDelegate oldDelegate) =>
      position != oldDelegate.position;
}

/// A horizontal divider line used to separate groups of menu items.
class BloomDropdownMenuSeparator extends StatelessWidget {
  /// Creates a [BloomDropdownMenuSeparator].
  const BloomDropdownMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: context.bloomColors.border,
    );
  }
}


