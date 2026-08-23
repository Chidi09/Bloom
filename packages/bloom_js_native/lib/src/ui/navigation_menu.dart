import '../framework.dart';
import '../router.dart';
import 'cn.dart';
import 'icons.dart';
import 'popover.dart';

/// Configuration descriptor for a navigation menu item.
class NavMenuItem {
  final String label;
  final String? href;
  final BloomNode? content;
  final bool active;

  const NavMenuItem({
    required this.label,
    this.href,
    this.content,
    this.active = false,
  });
}

/// Navigation menu component primitive.
///
/// Renders a horizontal navigation bar supporting both direct links and flyout panels.
BloomNode navigationMenu({
  required List<NavMenuItem> items,
  String extraClassName = '',
}) {
  return El(
    'nav',
    attrs: const {
      'data-slot': 'navigation-menu',
      'aria-label': 'Main',
    },
    className: cn([
      'relative flex items-center gap-1 select-none',
      extraClassName,
    ]),
    children: [
      El(
        'ul',
        attrs: const {'data-slot': 'navigation-menu-list'},
        className: 'flex list-none items-center gap-1 p-0 m-0',
        children: items.map((item) {
          final itemClass = cn([
            'inline-flex h-9 w-max items-center justify-center rounded-[var(--radius-md)] px-3 py-1.5 '
            'text-xs sm:text-sm font-medium transition-colors outline-none '
            'focus-visible:ring-2 focus-visible:ring-[var(--ring)] cursor-pointer',
            item.active
                ? 'bg-[var(--bg-muted)] text-[var(--text)]'
                : 'text-[var(--text-muted)] hover:bg-[var(--bg-muted)]/60 hover:text-[var(--text)]',
          ]);

          if (item.content != null) {
            // Dropdown flyout item
            return El(
              'li',
              attrs: const {'data-slot': 'navigation-menu-item'},
              children: [
                popover(
                  trigger: Div(
                    className: itemClass,
                    children: [
                      Span(text: item.label),
                      uiIcon('chevron-down', className: 'w-3.5 h-3.5 ml-1 opacity-70'),
                    ],
                  ),
                  content: item.content!,
                ),
              ],
            );
          }

          // Plain link item
          return El(
            'li',
            attrs: const {'data-slot': 'navigation-menu-item'},
            children: [
              Link(
                href: item.href ?? '#',
                className: itemClass,
                text: item.label,
              ),
            ],
          );
        }).toList(),
      ),
    ],
  );
}
