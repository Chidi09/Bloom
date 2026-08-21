// lib/src/primitives/dropdown_menu.dart
import 'package:flutter/material.dart';
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
/// Wraps a [PopupMenuButton] with Bloom tokens for styling, rounded corners,
/// elevation shadows, typography, and support for keyboard shortcuts and destructive items.
///
/// Example:
/// ```dart
/// BloomDropdownMenu(
///   trigger: OutlinedButton(
///     onPressed: null,
///     child: const Text('Options'),
///   ),
///   items: [
///     BloomDropdownMenuItem(
///       label: 'Edit',
///       icon: Icon(Icons.edit_outlined),
///       onTap: () => print('Edit tapped'),
///     ),
///     BloomDropdownMenuItem(
///       label: 'Delete',
///       icon: Icon(Icons.delete_outline),
///       isDestructive: true,
///       onTap: () => print('Delete tapped'),
///     ),
///   ],
/// );
/// ```
class BloomDropdownMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return PopupMenuButton<int>(
      tooltip: '',
      offset: const Offset(0, 6),
      color: colors.surface1,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      itemBuilder: (ctx) {
        return List.generate(items.length, (index) {
          final item = items[index];
          final textCol = item.isDestructive
              ? colors.destructive
              : item.disabled
                  ? colors.textTertiary
                  : colors.textPrimary;

          return PopupMenuItem<int>(
            value: index,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            enabled: !item.disabled,
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
          );
        });
      },
      onSelected: (index) {
        items[index].onTap?.call();
      },
      child: trigger,
    );
  }
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

