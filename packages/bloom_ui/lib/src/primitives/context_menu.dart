// lib/src/primitives/context_menu.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'dropdown_menu.dart';

/// A contextual overlay menu triggered by secondary click (right-click) or long-press gestures.
///
/// Wraps a [child] widget and responds to desktop secondary mouse clicks (`onSecondaryTapDown`)
/// and mobile long-press gestures (`onLongPressStart`), displaying a floating menu styled
/// with Bloom design tokens at the cursor/pointer coordinates.
///
/// Example:
/// ```dart
/// BloomContextMenu(
///   items: [
///     BloomDropdownMenuItem(
///       label: 'Copy',
///       icon: Icon(Icons.copy),
///       shortcut: Text('Ctrl+C'),
///       onTap: () => print('Copy'),
///     ),
///     BloomDropdownMenuItem(
///       label: 'Delete',
///       icon: Icon(Icons.delete_outline),
///       isDestructive: true,
///       onTap: () => print('Delete'),
///     ),
///   ],
///   child: Container(
///     padding: EdgeInsets.all(24),
///     child: Text('Right-click or long-press me'),
///   ),
/// );
/// ```
class BloomContextMenu extends StatelessWidget {
  /// The target widget that listens for right-click or long-press gestures.
  final Widget child;

  /// The list of items displayed inside the contextual menu.
  final List<BloomDropdownMenuItem> items;

  /// Width constraint of the contextual menu overlay. Defaults to `200`.
  final double width;

  /// Creates a [BloomContextMenu].
  ///
  /// * [child]: The target content that receives the gestures.
  /// * [items]: List of menu item definitions to display in the menu.
  /// * [width]: Width in logical pixels of the context menu popup (defaults to `200`).
  const BloomContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return GestureDetector(
      onSecondaryTapDown: (details) => _showMenu(context, details.globalPosition, colors),
      onLongPressStart: (details) => _showMenu(context, details.globalPosition, colors),
      child: child,
    );
  }

  void _showMenu(BuildContext context, Offset position, dynamic colors) {
    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + width,
        position.dy + 1,
      ),
      color: colors.surface1,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      items: List.generate(items.length, (index) {
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
      }),
    ).then((index) {
      if (index != null) items[index].onTap?.call();
    });
  }
}

