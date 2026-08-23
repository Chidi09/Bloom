import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Accordion item descriptor.
typedef AccordionItem = ({String id, String title, BloomNode content});

/// Accordion component primitive with local reactive state and smooth toggle animations.
///
/// If [allowMultiple] is true, multiple sections can be open at once.
/// [initialOpen] sets the set of item IDs that are open on initial render.
BloomNode accordion({
  required List<AccordionItem> items,
  bool allowMultiple = false,
  Set<String>? initialOpen,
  String extraClassName = '',
}) {
  final openIds = signal<Set<String>>(initialOpen ?? <String>{});

  return Div(
    attrs: const {'data-slot': 'accordion'},
    className: cn([
      'flex w-full flex-col overflow-hidden rounded-[var(--radius-md)] border border-[var(--border)] divide-y divide-[var(--border)] bg-[var(--card)]',
      extraClassName,
    ]),
    children: items.map((item) {
      return Div(
        attrs: const {'data-slot': 'accordion-item'},
        className: 'flex flex-col',
        children: [
          Live(() {
            final isOpen = openIds.value.contains(item.id);

            return El(
              'button',
              attrs: {
                'type': 'button',
                'data-slot': 'accordion-trigger',
                'aria-expanded': isOpen ? 'true' : 'false',
              },
              className: cn([
                'flex w-full items-center justify-between p-3.5 text-left text-xs sm:text-sm font-medium text-[var(--text)] transition-colors hover:bg-[var(--bg-muted)]/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)] select-none cursor-pointer',
                isOpen ? 'bg-[var(--bg-muted)]/30' : '',
              ]),
              onClick: (_) {
                final current = Set<String>.from(openIds.value);
                if (current.contains(item.id)) {
                  current.remove(item.id);
                } else {
                  if (!allowMultiple) current.clear();
                  current.add(item.id);
                }
                openIds.value = current;
              },
              children: [
                Span(text: item.title),
                Div(
                  className: cn([
                    'transition-transform duration-200 text-[var(--text-muted)]',
                    isOpen ? 'rotate-180' : '',
                  ]),
                  children: [
                    uiIcon('chevron-down', className: 'w-4 h-4 shrink-0'),
                  ],
                ),
              ],
            );
          }),
          Live(() {
            final isOpen = openIds.value.contains(item.id);
            if (!isOpen) return const Fragment(children: []);

            return Div(
              attrs: const {
                'data-slot': 'accordion-content',
                'role': 'region',
              },
              className:
                  'p-3.5 pt-0 text-xs sm:text-sm text-[var(--text-muted)] leading-relaxed',
              children: [item.content],
            );
          }),
        ],
      );
    }).toList(),
  );
}
