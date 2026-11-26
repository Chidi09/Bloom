import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Interactive tag-chip input allowing users to add and remove string tags.
BloomNode tagsInput({
  required Signal<List<String>> tags,
  String placeholder = 'Add tag...',
  int? maxTags,
  String extraClassName = '',
}) {
  final draft = signal<String>('');

  void addTag(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return;
    if (maxTags != null && tags.value.length >= maxTags) return;
    if (!tags.value.contains(clean)) {
      tags.value = [...tags.value, clean];
    }
    draft.value = '';
  }

  return Div(
    className: cn([
      'flex flex-wrap items-center gap-1.5 w-full rounded-[var(--radius-md)] border border-[var(--border)] '
          'bg-[var(--bg)] px-2.5 py-1.5 focus-within:ring-2 focus-within:ring-[var(--ring)]',
      extraClassName,
    ]),
    children: [
      Live(() => FragmentNode([
            for (final tag in tags.value)
              Span(
                className:
                    'inline-flex items-center gap-1 rounded-[var(--radius-sm)] bg-[var(--bg-muted)] px-2 py-0.5 text-xs font-medium text-[var(--text)]',
                children: [
                  Text(tag),
                  Button(
                    attrs: {
                      'type': 'button',
                      'aria-label': 'Remove $tag',
                    },
                    className:
                        'text-[var(--text-muted)] hover:text-[var(--text)]',
                    onClick: (_) {
                      tags.value =
                          tags.value.where((t) => t != tag).toList();
                    },
                    children: [uiIcon('x', className: 'w-3 h-3')],
                  ),
                ],
              ),
          ])),
      Input(
        type: 'text',
        placeholder: placeholder,
        attrs: {'aria-label': placeholder},
        className:
            'flex-1 min-w-24 bg-transparent text-sm text-[var(--text)] focus:outline-none',
        onInput: (e) => draft.value = e.value ?? '',
        onKeyDown: (e) {
          if (e.key == 'Enter' || e.key == ',') {
            e.preventDefault();
            addTag(draft.value);
          }
        },
      ),
    ],
  );
}
