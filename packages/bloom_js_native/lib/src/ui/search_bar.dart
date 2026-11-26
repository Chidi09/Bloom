import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';
import 'kbd.dart';

/// Search input bar with leading search icon, optional keyboard shortcut hint, and clear action.
BloomNode searchBar({
  required Signal<String> query,
  String placeholder = 'Search...',
  String? shortcutHint,
  void Function(String query)? onSubmit,
  String extraClassName = '',
}) {
  return Form(
    className: cn([
      'flex items-center gap-2 w-full rounded-[var(--radius-md)] border border-[var(--border)] '
          'bg-[var(--bg)] px-3 h-9 focus-within:ring-2 focus-within:ring-[var(--ring)]',
      extraClassName,
    ]),
    onSubmit: (e) {
      e.preventDefault();
      onSubmit?.call(query.value);
    },
    children: [
      uiIcon('search', className: 'w-4 h-4 text-[var(--text-muted)] shrink-0'),
      Input(
        type: 'search',
        placeholder: placeholder,
        value: query.value,
        attrs: {'aria-label': placeholder},
        className:
            'flex-1 bg-transparent text-sm text-[var(--text)] focus:outline-none',
        onInput: (e) => query.value = e.value ?? '',
      ),
      Show(
        () => query.value.isNotEmpty,
        child: Button(
          attrs: const {'type': 'button', 'aria-label': 'Clear search'},
          className: 'text-[var(--text-muted)] hover:text-[var(--text)]',
          onClick: (_) => query.value = '',
          children: [uiIcon('x', className: 'w-3.5 h-3.5')],
        ),
      ),
      if (shortcutHint != null) kbd(text: shortcutHint),
    ],
  );
}
