import '../events.dart';
import '../framework.dart';
import 'cn.dart';
import 'icons.dart';

/// Semantic variants for [banner].
enum BannerVariant {
  /// Neutral informational announcement.
  info,

  /// Positive confirmation announcement.
  success,

  /// Cautionary warning announcement.
  warning,

  /// Critical/error announcement.
  destructive,
}

/// Top-level announcement banner with optional title, action, and dismiss button.
BloomNode banner({
  required String message,
  String? title,
  BannerVariant variant = BannerVariant.info,
  BloomNode? action,
  BloomEventHandler? onDismiss,
  String extraClassName = '',
}) {
  final variantCls = switch (variant) {
    BannerVariant.info =>
      'border-[var(--border)] bg-[var(--bg-soft)] text-[var(--text)]',
    BannerVariant.success =>
      'border-[var(--success)]/40 bg-[var(--success)]/10 text-[var(--text)]',
    BannerVariant.warning =>
      'border-[var(--warning)]/40 bg-[var(--warning)]/10 text-[var(--text)]',
    BannerVariant.destructive =>
      'border-[var(--destructive)]/40 bg-[var(--destructive)]/10 text-[var(--destructive)]',
  };

  return Div(
    attrs: {
      'role': variant == BannerVariant.destructive ? 'alert' : 'status',
    },
    className: cn([
      'flex flex-wrap items-center justify-between gap-3 w-full rounded-[var(--radius-md)] border px-4 py-3 text-sm',
      variantCls,
      extraClassName,
    ]),
    children: [
      Div(
        className: 'flex-1 min-w-0 space-y-0.5',
        children: [
          if (title != null)
            Div(className: 'font-semibold', text: title),
          Div(className: 'text-xs sm:text-sm', text: message),
        ],
      ),
      Div(
        className: 'flex items-center gap-2 shrink-0',
        children: [
          if (action != null) action,
          if (onDismiss != null)
            Button(
              attrs: const {'type': 'button', 'aria-label': 'Dismiss banner'},
              className:
                  'p-1 rounded-[var(--radius-sm)] opacity-75 hover:opacity-100',
              onClick: onDismiss,
              children: [uiIcon('x', className: 'w-4 h-4')],
            ),
        ],
      ),
    ],
  );
}
