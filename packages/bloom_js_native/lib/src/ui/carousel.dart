import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Wraps a single slide inside [carousel].
BloomNode carouselItem({
  required BloomNode child,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {
      'role': 'group',
      'aria-roledescription': 'slide',
    },
    className: cn(['w-full shrink-0', extraClassName]),
    children: [child],
  );
}

/// Interactive slide carousel with previous/next controls and dot indicators.
BloomNode carousel({
  required List<BloomNode> items,
  Signal<int>? activeIndex,
  bool showControls = true,
  bool showIndicators = true,
  String ariaLabel = 'Carousel',
  String extraClassName = '',
}) {
  final current = activeIndex ?? signal<int>(0);

  void goTo(int index) {
    if (items.isEmpty) return;
    final wrapped = ((index % items.length) + items.length) % items.length;
    current.value = wrapped;
  }

  return Div(
    attrs: {
      'role': 'region',
      'aria-roledescription': 'carousel',
      'aria-label': ariaLabel,
    },
    className: cn([
      'relative w-full overflow-hidden rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--card)]',
      extraClassName,
    ]),
    children: [
      Live(() {
        if (items.isEmpty) {
          return const FragmentNode([]);
        }
        final idx = current.value.clamp(0, items.length - 1);
        return Div(
          className: 'w-full',
          children: [items[idx]],
        );
      }),
      if (showControls && items.length > 1)
        Div(
          className:
              'flex items-center justify-between gap-2 px-3 py-2 border-t border-[var(--border)] bg-[var(--bg-soft)]',
          children: [
            Button(
              attrs: const {
                'type': 'button',
                'aria-label': 'Previous slide',
              },
              className:
                  'inline-flex items-center justify-center h-8 w-8 rounded-[var(--radius-sm)] border border-[var(--border)] bg-[var(--bg)] text-[var(--text)] hover:bg-[var(--bg-muted)]',
              onClick: (_) => goTo(current.value - 1),
              children: [uiIcon('chevron-left', className: 'w-4 h-4')],
            ),
            if (showIndicators)
              Live(() {
                final idx = current.value.clamp(0, items.length - 1);
                return Div(
                  className: 'flex items-center gap-1.5',
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Button(
                        attrs: {
                          'type': 'button',
                          'aria-label': 'Go to slide ${i + 1}',
                          'aria-current': i == idx ? 'true' : 'false',
                        },
                        className: i == idx
                            ? 'h-2 w-5 rounded-full bg-[var(--primary)] transition-all'
                            : 'h-2 w-2 rounded-full bg-[var(--border)] hover:bg-[var(--text-muted)] transition-all',
                        onClick: (_) => goTo(i),
                      ),
                  ],
                );
              }),
            Button(
              attrs: const {
                'type': 'button',
                'aria-label': 'Next slide',
              },
              className:
                  'inline-flex items-center justify-center h-8 w-8 rounded-[var(--radius-sm)] border border-[var(--border)] bg-[var(--bg)] text-[var(--text)] hover:bg-[var(--bg-muted)]',
              onClick: (_) => goTo(current.value + 1),
              children: [uiIcon('chevron-right', className: 'w-4 h-4')],
            ),
          ],
        ),
    ],
  );
}
