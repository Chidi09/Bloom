import '../framework.dart';
import '../signals.dart';
import 'cn.dart';

/// Disclosure container toggling [content] visibility when [trigger] is clicked.
BloomNode collapsible({
  required BloomNode trigger,
  required BloomNode content,
  Signal<bool>? open,
  bool defaultOpen = false,
  String extraClassName = '',
}) {
  final isOpen = open ?? signal<bool>(defaultOpen);

  return Div(
    reactiveAttrs: {
      'data-state': () => isOpen.value ? 'open' : 'closed',
    },
    className: cn(['w-full', extraClassName]),
    children: [
      Div(
        attrs: const {'data-testid': 'collapsible-trigger'},
        reactiveAttrs: {
          'aria-expanded': () => isOpen.value ? 'true' : 'false',
        },
        className: 'cursor-pointer',
        onClick: (_) => isOpen.value = !isOpen.value,
        children: [trigger],
      ),
      Show(
        () => isOpen.value,
        child: Div(
          className: 'pt-2',
          children: [content],
        ),
      ),
    ],
  );
}
