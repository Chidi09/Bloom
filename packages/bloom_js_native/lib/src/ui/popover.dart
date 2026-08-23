import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'cn.dart';

/// Popover container with per-instance reactive state and backdrop click-to-close.
BloomNode popover({
  required BloomNode trigger,
  required BloomNode content,
  String align = 'center',
  String extraClassName = '',
}) {
  final isOpen = signal<bool>(false);

  String alignClass;
  switch (align) {
    case 'left':
      alignClass = 'left-0';
      break;
    case 'right':
      alignClass = 'right-0';
      break;
    case 'center':
    default:
      alignClass = 'left-1/2 -translate-x-1/2';
      break;
  }

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
            // Floating popover card
            Div(
              attrs: const {'role': 'dialog'},
              className: cn([
                'absolute mt-2 z-50 rounded-[var(--radius-md)] border border-[var(--border)] '
                'bg-[var(--popover)] text-[var(--popover-foreground)] shadow-[var(--shadow-overlay)] '
                'p-4 outline-none',
                alignClass,
              ]),
              onClick: (BloomEvent e) => e.stopPropagation(),
              children: [content],
            ),
          ],
        );
      }),
    ],
  );
}
