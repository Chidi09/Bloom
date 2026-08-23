import 'package:bloom_js_native/bloom_js_native.dart';
import 'cn.dart';
import 'ui.dart';

typedef VoidCallback = void Function();

class MenuItemConfig {
  final String label;
  final String? href;
  final VoidCallback? onClick;
  final String? icon;
  final bool destructive;

  const MenuItemConfig({
    required this.label,
    this.href,
    this.onClick,
    this.icon,
    this.destructive = false,
  });
}

/// Dropdown actions menu with local reactive state and backdrop click-to-close.
BloomNode dropdownMenu({
  required BloomNode trigger,
  required List<MenuItemConfig> items,
}) {
  final isOpen = signal<bool>(false);

  return Div(
    className: 'relative inline-block text-left',
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
            // Backdrop click-catcher
            Div(
              className: 'fixed inset-0 z-40',
              onClick: (BloomEvent e) {
                e.stopPropagation();
                isOpen.value = false;
              },
            ),
            // Menu panel
            Div(
              attrs: const {
                'role': 'menu',
                'aria-orientation': 'vertical',
              },
              className:
                  'absolute right-0 mt-2 min-w-[180px] rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--card)] shadow-[var(--shadow-overlay)] p-1 z-50 flex flex-col gap-0.5',
              onClick: (BloomEvent e) => e.stopPropagation(),
              children: items.map((item) {
                final itemClass = cn([
                  'px-2.5 py-1.5 text-sm rounded-[var(--radius-sm)] hover:bg-[var(--bg-muted)] flex items-center gap-2 text-left w-full transition-colors cursor-pointer',
                  item.destructive ? 'text-[var(--danger)]' : 'text-[var(--text)]',
                ]);
                final content = [
                  if (item.icon != null) hugeIcon(item.icon!, className: 'w-4 h-4 shrink-0'),
                  Span(text: item.label),
                ];

                if (item.href != null) {
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
                  attrs: const {'type': 'button', 'role': 'menuitem'},
                  className: itemClass,
                  onClick: (BloomEvent e) {
                    isOpen.value = false;
                    item.onClick?.call();
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
