import '../framework.dart';
import 'cn.dart';

/// Controlled tabs component.
///
/// Renders a tab navigation strip and the active tab panel returned by [content].
BloomNode tabs({
  required List<({String key, String label})> items,
  required String activeKey,
  required void Function(String key) onChange,
  required BloomNode Function(String key) content,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['flex flex-col gap-4', extraClassName]),
    children: [
      Div(
        attrs: const {'role': 'tablist'},
        className:
            'inline-flex h-9 w-fit items-center justify-center rounded-[var(--radius-md)] '
            'bg-[var(--muted)] p-1 text-[var(--muted-foreground)] gap-1 select-none',
        children: items.map((item) {
          final isActive = item.key == activeKey;
          return El(
            'button',
            attrs: {
              'type': 'button',
              'role': 'tab',
              'aria-selected': isActive ? 'true' : 'false',
            },
            className: cn([
              'inline-flex items-center justify-center whitespace-nowrap rounded-[var(--radius-sm)] '
              'px-3 py-1 text-xs sm:text-sm font-medium transition-all focus-visible:outline-none '
              'focus-visible:ring-2 focus-visible:ring-[var(--ring)] focus-visible:ring-offset-2 '
              'disabled:pointer-events-none disabled:opacity-50 cursor-pointer',
              isActive
                  ? 'bg-[var(--card)] text-[var(--text)] shadow-sm'
                  : 'hover:text-[var(--text)]',
            ]),
            onClick: (_) => onChange(item.key),
            text: item.label,
          );
        }).toList(),
      ),
      Div(
        attrs: const {'role': 'tabpanel'},
        className: 'focus-visible:outline-none',
        children: [
          content(activeKey),
        ],
      ),
    ],
  );
}
