// lib/src/primitives/menubar.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';
import 'dropdown_menu.dart';

/// A top-level menu entry for [BloomMenubar], containing a list of dropdown items.
class BloomMenubarMenu {
  /// The title label of the menu displayed in the menubar strip.
  final String title;

  /// The dropdown menu items revealed when this menu entry is activated.
  final List<BloomDropdownMenuItem> items;

  /// Creates a [BloomMenubarMenu].
  ///
  /// * [title]: Label string for the menu header (e.g. 'File', 'Edit', 'View').
  /// * [items]: List of dropdown items for this menu category.
  const BloomMenubarMenu({required this.title, required this.items});
}

/// A desktop application menubar bar component.
///
/// Arranges top-level [menus] horizontally in a compact toolbar container with
/// surface tokens, borders, and rounded corners. Clicking any menu header opens its
/// dropdown menu of actions.
///
/// Example:
/// ```dart
/// BloomMenubar(
///   menus: [
///     BloomMenubarMenu(
///       title: 'File',
///       items: [
///         BloomDropdownMenuItem(label: 'New Tab', shortcut: Text('Ctrl+T')),
///         BloomDropdownMenuItem(label: 'Close Window', shortcut: Text('Ctrl+W')),
///       ],
///     ),
///     BloomMenubarMenu(
///       title: 'Edit',
///       items: [
///         BloomDropdownMenuItem(label: 'Undo', shortcut: Text('Ctrl+Z')),
///         BloomDropdownMenuItem(label: 'Redo', shortcut: Text('Ctrl+Y')),
///       ],
///     ),
///   ],
/// );
/// ```
class BloomMenubar extends StatefulWidget {
  /// The collection of menu items displayed in this menubar.
  final List<BloomMenubarMenu> menus;

  /// Creates a [BloomMenubar].
  ///
  /// * [menus]: The list of top-level menus to render in the horizontal bar.
  const BloomMenubar({super.key, required this.menus});

  @override
  State<BloomMenubar> createState() => _BloomMenubarState();
}

class _BloomMenubarState extends State<BloomMenubar> {
  /// Coordinates the sibling menus so that only one panel is open at a time.
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final menus = widget.menus;

    return Container(
      height: 36, // h-9
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: RawMenuAnchorGroup(
        controller: _controller,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: menus.map((menu) {
            return BloomDropdownMenu(
              trigger: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  menu.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: context.bloomTypography.sans,
                  ),
                ),
              ),
              items: menu.items,
            );
          }).toList(),
        ),
      ),
    );
  }
}


