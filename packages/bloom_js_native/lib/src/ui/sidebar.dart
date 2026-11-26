import '../events.dart';
import '../framework.dart';
import '../router.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

/// Expandable application navigation sidebar.
BloomNode sidebar({
  required List<BloomNode> children,
  BloomNode? header,
  BloomNode? footer,
  Signal<bool>? collapsed,
  String ariaLabel = 'Sidebar navigation',
  String extraClassName = '',
}) {
  final isCollapsed = collapsed;
  return Aside(
    attrs: {'aria-label': ariaLabel},
    reactiveClass: isCollapsed == null
        ? null
        : () => cn([
              'flex flex-col justify-between h-full border-r border-[var(--border)] bg-[var(--bg-soft)] transition-all',
              isCollapsed.value ? 'w-16 px-2 py-3' : 'w-64 px-3 py-4',
              extraClassName,
            ]),
    className: isCollapsed != null
        ? null
        : cn([
            'flex flex-col justify-between w-64 h-full border-r border-[var(--border)] bg-[var(--bg-soft)] px-3 py-4',
            extraClassName,
          ]),
    children: [
      if (header != null) Div(className: 'mb-4', children: [header]),
      Div(className: 'flex-1 space-y-4 overflow-y-auto', children: children),
      if (footer != null)
        Div(
          className: 'mt-4 pt-3 border-t border-[var(--border)]',
          children: [footer],
        ),
    ],
  );
}

/// Labeled navigation group inside [sidebar].
BloomNode sidebarGroup({
  String? label,
  required List<BloomNode> children,
  String extraClassName = '',
}) {
  return Div(
    className: cn(['space-y-1', extraClassName]),
    children: [
      if (label != null)
        Div(
          className:
              'px-2.5 py-1 text-xs font-semibold uppercase tracking-wider text-[var(--text-faint)]',
          text: label,
        ),
      ...children,
    ],
  );
}

/// Navigation item inside a [sidebarGroup].
BloomNode sidebarItem({
  required String label,
  String? href,
  String? icon,
  BloomNode? badge,
  bool active = false,
  BloomEventHandler? onClick,
  String extraClassName = '',
}) {
  final cls = cn([
    'flex w-full items-center justify-between gap-2 px-2.5 py-2 rounded-[var(--radius-md)] text-sm font-medium transition-colors',
    active
        ? 'bg-[var(--bg-muted)] text-[var(--text)]'
        : 'text-[var(--text-muted)] hover:bg-[var(--bg-muted)] hover:text-[var(--text)]',
    extraClassName,
  ]);
  final content = <BloomNode>[
    Div(
      className: 'flex items-center gap-2.5 min-w-0',
      children: [
        if (icon != null) uiIcon(icon, className: 'w-4 h-4 shrink-0'),
        Span(className: 'truncate', text: label),
      ],
    ),
    if (badge != null) badge,
  ];

  if (href != null) {
    return Link(
      href: href,
      attrs: {if (active) 'aria-current': 'page'},
      className: cls,
      onClick: onClick,
      children: content,
    );
  }

  return Button(
    attrs: {
      'type': 'button',
      if (active) 'aria-current': 'page',
    },
    className: cls,
    onClick: onClick,
    children: content,
  );
}
