import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

enum BadgeVariant {
  defaultVariant,
  secondary,
  destructive,
  outline,
  success,
  warning,
  info,
}

/// Generic badge primitive for Bloom UI.
BloomNode badge({
  required String label,
  BadgeVariant variant = BadgeVariant.defaultVariant,
  void Function()? onDismiss,
  String? icon,
  String extraClassName = '',
}) {
  String variantClasses;
  switch (variant) {
    case BadgeVariant.defaultVariant:
      variantClasses =
          'border-transparent bg-[var(--primary)] text-[var(--primary-foreground)]';
      break;
    case BadgeVariant.secondary:
      variantClasses =
          'border-transparent bg-[var(--secondary)] text-[var(--secondary-foreground)]';
      break;
    case BadgeVariant.destructive:
      variantClasses =
          'border-transparent bg-[var(--destructive)] text-[var(--destructive-foreground)]';
      break;
    case BadgeVariant.outline:
      variantClasses =
          'border-[var(--border)] text-[var(--text)] bg-transparent';
      break;
    case BadgeVariant.success:
      variantClasses =
          'border-transparent bg-[var(--success)] text-[var(--success-foreground)]';
      break;
    case BadgeVariant.warning:
      variantClasses =
          'border-transparent bg-[var(--warning)] text-[var(--warning-foreground)]';
      break;
    case BadgeVariant.info:
      variantClasses =
          'border-transparent bg-[var(--info)] text-[var(--info-foreground)]';
      break;
  }

  return Span(
    className: cn([
      'inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium border select-none',
      variantClasses,
      extraClassName,
    ]),
    children: [
      if (icon != null) uiIcon(icon, className: 'w-3 h-3'),
      Text(label),
      if (onDismiss != null)
        El(
          'button',
          attrs: const {
            'type': 'button',
            'aria-label': 'Dismiss badge',
          },
          className:
              'cursor-pointer hover:opacity-75 transition-opacity inline-flex items-center p-0.5 -mr-1',
          onClick: (_) => onDismiss(),
          children: [
            uiIcon('x', className: 'w-3 h-3'),
          ],
        ),
    ],
  );
}
