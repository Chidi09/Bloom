import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'dropdown_menu.dart';
import 'icons.dart';

/// Context menu descriptor triggered by right-click.
///
/// Reuses [MenuItemConfig] from `dropdown_menu.dart`.
BloomNode contextMenu({
  required BloomNode child,
  required List<MenuItemConfig> items,
  String extraClassName = '',
}) {
  final isOpen = signal<bool>(false);
  final position = signal<({double x, double y})>((x: 0.0, y: 0.0));

  return Div(
    className: cn(['relative inline-block', extraClassName]),
    on: {
      'contextmenu': (BloomEvent e) {
        e.preventDefault();
        e.stopPropagation();
        final x = e.clientX ?? e.offsetX ?? 0.0;
        final y = e.clientY ?? e.offsetY ?? 0.0;
        position.value = (x: x, y: y);
        isOpen.value = true;
      },
    },
    children: [
      child,
      Live(() {
        if (!isOpen.value) return const Fragment(children: []);

        final pos = position.value;
        final isFixed = pos.x > 0 || pos.y > 0;

        return Fragment(
          children: [
            // Full-screen backdrop
            Div(
              className: 'fixed inset-0 z-50',
              on: {
                'click': (BloomEvent e) {
                  e.stopPropagation();
                  isOpen.value = false;
                },
                'contextmenu': (BloomEvent e) {
                  e.preventDefault();
                  e.stopPropagation();
                  isOpen.value = false;
                },
              },
            ),
            // Floating context menu panel
            Div(
              attrs: const {
                'role': 'menu',
                'aria-orientation': 'vertical',
              },
              style: isFixed ? 'left: ${pos.x}px; top: ${pos.y}px;' : null,
              className: cn([
                isFixed ? 'fixed' : 'absolute left-0 top-full mt-1',
                'min-w-[180px] rounded-[var(--radius-md)] border border-[var(--border)] '
                'bg-[var(--card)] shadow-[var(--shadow-overlay)] p-1 z-50 flex flex-col gap-0.5',
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
