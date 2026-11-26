import '../events.dart';
import '../framework.dart';
import 'cn.dart';

/// Flexible list item row with leading, title/subtitle, and trailing slots.
BloomNode uiItem({
  required String title,
  String? subtitle,
  BloomNode? leading,
  BloomNode? trailing,
  BloomEventHandler? onClick,
  bool active = false,
  String extraClassName = '',
}) {
  return Div(
    attrs: {
      if (onClick != null) 'role': 'button',
      if (onClick != null) 'tabindex': '0',
      if (active) 'aria-current': 'true',
    },
    className: cn([
      'flex items-center justify-between gap-3 px-3 py-2.5 rounded-[var(--radius-md)] border transition-colors',
      active
          ? 'border-[var(--primary)] bg-[var(--bg-muted)]'
          : 'border-transparent hover:bg-[var(--bg-soft)]',
      if (onClick != null) 'cursor-pointer',
      extraClassName,
    ]),
    onClick: onClick,
    children: [
      Div(
        className: 'flex items-center gap-3 min-w-0',
        children: [
          if (leading != null) leading,
          Div(
            className: 'min-w-0',
            children: [
              Div(
                className:
                    'text-sm font-medium text-[var(--text)] truncate',
                text: title,
              ),
              if (subtitle != null)
                Div(
                  className:
                      'text-xs text-[var(--text-muted)] truncate',
                  text: subtitle,
                ),
            ],
          ),
        ],
      ),
      if (trailing != null) Div(className: 'shrink-0', children: [trailing]),
    ],
  );
}
