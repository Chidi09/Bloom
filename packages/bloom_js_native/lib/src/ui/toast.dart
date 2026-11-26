import '../events.dart';
import '../framework.dart';
import 'cn.dart';
import 'icons.dart';
import 'sonner.dart' show ToastVariant;

/// Standalone floating toast notification card.
BloomNode toastBanner({
  required String title,
  String? description,
  ToastVariant variant = ToastVariant.info,
  BloomEventHandler? onDismiss,
  String extraClassName = '',
}) {
  final variantCls = switch (variant) {
    ToastVariant.info =>
      'border-[var(--border)] bg-[var(--card)] text-[var(--card-foreground)]',
    ToastVariant.success =>
      'border-[var(--success)]/40 bg-[var(--card)] text-[var(--text)]',
    ToastVariant.warning =>
      'border-[var(--warning)]/40 bg-[var(--card)] text-[var(--text)]',
    ToastVariant.error =>
      'border-[var(--destructive)]/40 bg-[var(--card)] text-[var(--text)]',
  };

  return Div(
    attrs: const {
      'role': 'status',
      'aria-live': 'polite',
    },
    className: cn([
      'flex items-start justify-between gap-3 w-full max-w-sm rounded-[var(--radius-md)] border p-4 shadow-[var(--shadow-overlay)]',
      variantCls,
      extraClassName,
    ]),
    children: [
      Div(
        className: 'space-y-1',
        children: [
          Div(className: 'text-sm font-semibold', text: title),
          if (description != null)
            Div(
              className: 'text-xs text-[var(--text-muted)]',
              text: description,
            ),
        ],
      ),
      if (onDismiss != null)
        Button(
          attrs: const {'type': 'button', 'aria-label': 'Dismiss notification'},
          className:
              'text-[var(--text-muted)] hover:text-[var(--text)] p-1 rounded-[var(--radius-sm)]',
          onClick: onDismiss,
          children: [uiIcon('x', className: 'w-4 h-4')],
        ),
    ],
  );
}
