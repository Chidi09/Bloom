import '../framework.dart';
import 'cn.dart';
import 'dropdown_menu.dart';

/// Single top-level menu in a [menubar].
typedef MenubarItem = ({String label, List<MenuItemConfig> items});

/// Menubar component primitive.
///
/// Renders a horizontal desktop-style menu bar composed of dropdown menus.
BloomNode menubar({
  required List<MenubarItem> menus,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {
      'role': 'menubar',
      'aria-orientation': 'horizontal',
    },
    className: cn([
      'flex h-9 items-center rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--card)] p-1 gap-1 select-none',
      extraClassName,
    ]),
    children: menus.map((menu) {
      return dropdownMenu(
        trigger: El(
          'button',
          attrs: const {
            'type': 'button',
            'role': 'menuitem',
          },
          className:
              'flex items-center rounded-[var(--radius-sm)] px-2.5 py-1 text-xs font-medium text-[var(--text)] '
              'hover:bg-[var(--bg-muted)] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)] cursor-pointer',
          text: menu.label,
        ),
        items: menu.items,
        align: 'left',
      );
    }).toList(),
  );
}
