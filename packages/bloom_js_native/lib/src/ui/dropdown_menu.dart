import '../events.dart';
import '../framework.dart';
import '../router.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Configuration for a dropdown menu item.
class MenuItemConfig {
  final String label;
  final String? href;
  final void Function()? onClick;
  final String? icon;
  final bool destructive;
  final bool disabled;

  const MenuItemConfig({
    required this.label,
    this.href,
    this.onClick,
    this.icon,
    this.destructive = false,
    this.disabled = false,
  });
}

/// Dropdown actions menu with local reactive state and backdrop click-to-close.
BloomNode dropdownMenu({
  required BloomNode trigger,
  required List<MenuItemConfig> items,
  String align = 'right',
  String extraClassName = '',
}) {
  final isOpen = signal<bool>(false);

  final alignClass = align == 'left' ? 'left-0' : 'right-0';

  return Div(
    className: cn(['relative inline-block text-left', extraClassName]),
    children: [
      Div(
        className: 'inline-flex cursor-pointer',
        onClick: (BloomEvent e) {
          e.stopPropagation();
          isOpen.value = !isOpen.value;
        },
        children: [trigger],
      ),
      Live(() {
        if (!isOpen.value) return const Fragment(children: []);

        return Fragment(
          children: [
            // Full-screen backdrop click-catcher
            Div(
              className: 'fixed inset-0 z-40',
              onClick: (BloomEvent e) {
                e.stopPropagation();
                isOpen.value = false;
              },
            ),
            // Floating menu panel
            Div(
              attrs: const {
                'role': 'menu',
                'aria-orientation': 'vertical',
              },
              className: cn([
                'absolute mt-2 min-w-[180px] rounded-[var(--radius-md)] border border-[var(--border)] '
                'bg-[var(--card)] shadow-[var(--shadow-overlay)] p-1 z-50 flex flex-col gap-0.5',
                alignClass,
              ]),
              onClick: (BloomEvent e) => e.stopPropagation(),
              children: items.map((item) {
                final itemClass = cn([
                  'px-2.5 py-1.5 text-xs sm:text-sm rounded-[var(--radius-sm)] flex items-center gap-2 text-left w-full transition-colors select-none',
                  item.disabled
                      ? 'opacity-50 cursor-not-allowed pointer-events-none'
                      : 'cursor-pointer hover:bg-[var(--bg-muted)]',
                  item.destructive
                      ? 'text-[var(--destructive)]'
                      : 'text-[var(--text)]',
                ]);

                final content = <BloomNode>[
                  if (item.icon != null)
                    uiIcon(item.icon!, className: 'w-4 h-4 shrink-0'),
                  Span(text: item.label),
                ];

                if (item.href != null && !item.disabled) {
                  return Link(
                    href: item.href!,
                    attrs: const {'role': 'menuitem'},
                    className: itemClass,
                    onClick: (BloomEvent e) {
                      isOpen.value = false;
                    },
                    children: content,
                  );
                }

                return El(
                  'button',
                  attrs: {
                    'type': 'button',
                    'role': 'menuitem',
                    if (item.disabled) 'disabled': 'true',
                  },
                  className: itemClass,
                  onClick: (BloomEvent e) {
                    isOpen.value = false;
                    if (!item.disabled) {
                      item.onClick?.call();
                    }
                  },
                  children: content,
                );
              }).toList(),
            ),
          ],
        );
      }),
    ],
  );
}
