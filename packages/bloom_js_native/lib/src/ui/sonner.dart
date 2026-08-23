import 'dart:async';
import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'icons.dart';

enum ToastVariant {
  info,
  success,
  warning,
  error,
}

/// Descriptor representing an active toast notification item.
class ToastItem {
  final String id;
  final String message;
  final ToastVariant variant;
  final DateTime createdAt;
  final String? actionLabel;
  final void Function()? onAction;

  ToastItem({
    required this.id,
    required this.message,
    required this.variant,
    required this.createdAt,
    this.actionLabel,
    this.onAction,
  });
}

/// Global reactive signal list of active toast items.
final Signal<List<ToastItem>> toastList = signal<List<ToastItem>>([]);
int _toastIdCounter = 0;

/// Dispatches a toast notification to the global toast queue.
void showToast(
  String message, {
  ToastVariant variant = ToastVariant.info,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  void Function()? onAction,
}) {
  final id =
      'toast_${DateTime.now().millisecondsSinceEpoch}_${++_toastIdCounter}';
  final item = ToastItem(
    id: id,
    message: message,
    variant: variant,
    createdAt: DateTime.now(),
    actionLabel: actionLabel,
    onAction: onAction,
  );
  toastList.value = [...toastList.value, item];

  Timer(duration, () {
    dismissToast(id);
  });
}

/// Dismisses a toast by its [id].
void dismissToast(String id) {
  toastList.value = toastList.value.where((t) => t.id != id).toList();
}

/// Viewport container mounted at application root to render active toasts.
BloomNode toastViewport() {
  return Live(() {
    final list = toastList.value;
    if (list.isEmpty) return const Fragment(children: []);

    return Div(
      className:
          'fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none px-4 sm:px-0',
      children: list.map((t) => _toastCard(t)).toList(),
    );
  });
}

BloomNode _toastCard(ToastItem item) {
  String border;
  String icon;
  String role;
  String iconColor;

  switch (item.variant) {
    case ToastVariant.success:
      border = 'border-[var(--success)]/40';
      icon = 'check';
      iconColor = 'text-[var(--success)]';
      role = 'status';
      break;
    case ToastVariant.error:
      border = 'border-[var(--destructive)]/40';
      icon = 'alert';
      iconColor = 'text-[var(--destructive)]';
      role = 'alert';
      break;
    case ToastVariant.warning:
      border = 'border-[var(--warning)]/40';
      icon = 'alert';
      iconColor = 'text-[var(--warning)]';
      role = 'status';
      break;
    case ToastVariant.info:
      border = 'border-[var(--info)]/40';
      icon = 'info';
      iconColor = 'text-[var(--info)]';
      role = 'status';
      break;
  }

  return Div(
    attrs: {
      'role': role,
      'aria-live': item.variant == ToastVariant.error ? 'assertive' : 'polite',
    },
    className: cn([
      'pointer-events-auto flex items-center justify-between gap-3 p-3.5 '
      'rounded-[var(--radius-md)] border bg-[var(--card)] text-[var(--card-foreground)] '
      'shadow-[var(--shadow-overlay)] transition-all duration-200',
      border,
    ]),
    children: [
      Div(
        className: 'flex items-center gap-2.5 min-w-0 flex-1',
        children: [
          Span(
            className: cn(['shrink-0', iconColor]),
            children: [uiIcon(icon, className: 'w-4 h-4')],
          ),
          Span(
            className: 'text-sm font-medium leading-snug line-clamp-2',
            text: item.message,
          ),
        ],
      ),
      if (item.actionLabel != null && item.onAction != null)
        El(
          'button',
          attrs: const {'type': 'button'},
          className:
              'shrink-0 text-xs font-semibold text-[var(--primary)] hover:underline cursor-pointer',
          onClick: (_) {
            item.onAction!();
            dismissToast(item.id);
          },
          text: item.actionLabel!,
        ),
      El(
        'button',
        attrs: const {
          'type': 'button',
          'aria-label': 'Dismiss alert',
        },
        className:
          'shrink-0 p-1 rounded-[var(--radius-sm)] text-[var(--text-muted)] hover:text-[var(--text)] '
          'hover:bg-[var(--bg-muted)] transition-colors cursor-pointer',
        onClick: (BloomEvent e) {
          e.preventDefault();
          dismissToast(item.id);
        },
        children: [
          uiIcon('x', className: 'w-3.5 h-3.5'),
        ],
      ),
    ],
  );
}
