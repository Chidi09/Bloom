import '../events.dart';
import '../framework.dart';
import '../router.dart';
import 'cn.dart';
import 'icons.dart';

enum ButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  link,
}

enum ButtonSize {
  sm,
  md,
  lg,
  icon,
}

/// Resolves CSS classes for [ButtonVariant] and [ButtonSize].
String buttonClasses({
  ButtonVariant variant = ButtonVariant.primary,
  ButtonSize size = ButtonSize.md,
  String extraClassName = '',
}) {
  const base =
      'inline-flex items-center justify-center gap-1.5 font-medium transition-colors '
      'select-none focus-visible:outline-none focus-visible:ring-2 '
      'focus-visible:ring-[var(--ring)] focus-visible:ring-offset-2 '
      'disabled:opacity-50 disabled:pointer-events-none rounded-[var(--radius-md)]';

  String sizeClass;
  switch (size) {
    case ButtonSize.sm:
      sizeClass = 'h-8 px-2.5 text-xs';
      break;
    case ButtonSize.md:
      sizeClass = 'h-9 px-4 py-2 text-sm';
      break;
    case ButtonSize.lg:
      sizeClass = 'h-10 px-5 text-base';
      break;
    case ButtonSize.icon:
      sizeClass = 'h-9 w-9 p-0';
      break;
  }

  String variantClass;
  switch (variant) {
    case ButtonVariant.primary:
      variantClass =
          'bg-[var(--primary)] text-[var(--primary-foreground)] hover:bg-[var(--primary-hover)]';
      break;
    case ButtonVariant.secondary:
      variantClass =
          'bg-[var(--secondary)] text-[var(--secondary-foreground)] hover:bg-[var(--secondary-hover)]';
      break;
    case ButtonVariant.outline:
      variantClass =
          'border border-[var(--border)] bg-transparent text-[var(--text)] hover:bg-[var(--bg-muted)]';
      break;
    case ButtonVariant.ghost:
      variantClass =
          'bg-transparent text-[var(--text)] hover:bg-[var(--bg-muted)]';
      break;
    case ButtonVariant.destructive:
      variantClass =
          'bg-[var(--destructive)] text-[var(--destructive-foreground)] hover:bg-[var(--danger-hover)]';
      break;
    case ButtonVariant.link:
      variantClass =
          'text-[var(--primary)] underline-offset-4 hover:underline bg-transparent p-0 h-auto';
      break;
  }

  return cn([base, sizeClass, variantClass, extraClassName]);
}

/// Generic Button primitive for Bloom UI.
BloomNode button({
  required String text,
  BloomEventHandler? onClick,
  String? href,
  ButtonVariant variant = ButtonVariant.primary,
  ButtonSize size = ButtonSize.md,
  bool disabled = false,
  String? icon,
  bool loading = false,
  String extraClassName = '',
  Map<String, String> attrs = const {},
  List<BloomNode>? children,
}) {
  final isInactive = disabled || loading;
  final className = buttonClasses(
    variant: variant,
    size: size,
    extraClassName: isInactive
        ? cn(['opacity-50 pointer-events-none', extraClassName])
        : extraClassName,
  );

  final content = <BloomNode>[
    if (loading)
      uiIcon('spinner', className: 'w-4 h-4 animate-spin')
    else if (icon != null)
      uiIcon(icon, className: 'w-4 h-4'),
    if (text.isNotEmpty) Text(text),
    if (children != null) ...children,
  ];

  if (href != null && !isInactive) {
    return Link(
      href: href,
      className: className,
      attrs: attrs,
      onClick: onClick,
      children: content,
    );
  }

  return El(
    'button',
    attrs: {
      'type': 'button',
      if (isInactive) 'disabled': 'true',
      if (isInactive) 'aria-disabled': 'true',
      ...attrs,
    },
    className: className,
    onClick: isInactive ? null : onClick,
    children: content,
  );
}
