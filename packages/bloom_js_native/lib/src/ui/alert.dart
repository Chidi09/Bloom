import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

enum AlertVariant {
  info,
  success,
  warning,
  destructive,
}

/// Static inline alert banner primitive.
BloomNode alert({
  required String title,
  String? description,
  AlertVariant variant = AlertVariant.info,
  String? icon,
  BloomNode? action,
  String extraClassName = '',
}) {
  String borderBgClass;
  String iconColorClass;
  String defaultIcon;

  switch (variant) {
    case AlertVariant.info:
      borderBgClass = 'border-[var(--info)]/30 bg-[var(--info)]/10 text-[var(--text)]';
      iconColorClass = 'text-[var(--info)]';
      defaultIcon = 'info';
      break;
    case AlertVariant.success:
      borderBgClass =
          'border-[var(--success)]/30 bg-[var(--success)]/10 text-[var(--text)]';
      iconColorClass = 'text-[var(--success)]';
      defaultIcon = 'check';
      break;
    case AlertVariant.warning:
      borderBgClass =
          'border-[var(--warning)]/30 bg-[var(--warning)]/10 text-[var(--text)]';
      iconColorClass = 'text-[var(--warning)]';
      defaultIcon = 'alert';
      break;
    case AlertVariant.destructive:
      borderBgClass =
          'border-[var(--destructive)]/30 bg-[var(--destructive)]/10 text-[var(--text)]';
      iconColorClass = 'text-[var(--destructive)]';
      defaultIcon = 'alert';
      break;
  }

  return Div(
    attrs: const {'role': 'alert'},
    className: cn([
      'relative w-full rounded-[var(--radius-md)] border p-4 text-sm flex gap-3 items-start',
      borderBgClass,
      extraClassName,
    ]),
    children: [
      Span(
        className: cn(['shrink-0 mt-0.5', iconColorClass]),
        children: [uiIcon(icon ?? defaultIcon, className: 'w-4 h-4')],
      ),
      Div(
        className: 'flex-1 flex flex-col gap-1',
        children: [
          H5(
            className: 'font-medium leading-none tracking-tight text-[var(--text)]',
            text: title,
          ),
          if (description != null && description.isNotEmpty)
            P(
              className: 'text-xs text-[var(--text-muted)] leading-relaxed',
              text: description,
            ),
        ],
      ),
      if (action != null)
        Div(
          className: 'shrink-0 self-center',
          children: [action],
        ),
    ],
  );
}
