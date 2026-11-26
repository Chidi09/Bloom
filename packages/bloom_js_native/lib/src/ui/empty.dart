import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

/// Structured empty-state container with icon, title, description, and optional action.
BloomNode empty({
  required String title,
  String? description,
  String? icon,
  BloomNode? action,
  String extraClassName = '',
}) {
  return Div(
    attrs: const {'role': 'status'},
    className: cn([
      'flex flex-col items-center justify-center text-center p-8 rounded-[var(--radius-lg)] '
          'border border-dashed border-[var(--border)] bg-[var(--bg-soft)] gap-3',
      extraClassName,
    ]),
    children: [
      if (icon != null)
        Div(
          className:
              'flex h-10 w-10 items-center justify-center rounded-full bg-[var(--bg-muted)] text-[var(--text-muted)]',
          children: [uiIcon(icon, className: 'w-5 h-5')],
        ),
      Div(
        className: 'space-y-1',
        children: [
          H3(
            className: 'text-base font-semibold text-[var(--text)]',
            text: title,
          ),
          if (description != null)
            P(
              className: 'text-sm text-[var(--text-muted)] max-w-sm',
              text: description,
            ),
        ],
      ),
      if (action != null) Div(className: 'pt-1', children: [action]),
    ],
  );
}

/// Alias for [empty] matching composite naming conventions.
BloomNode emptyState({
  required String title,
  String? description,
  String? icon,
  BloomNode? action,
  String extraClassName = '',
}) =>
    empty(
      title: title,
      description: description,
      icon: icon,
      action: action,
      extraClassName: extraClassName,
    );
