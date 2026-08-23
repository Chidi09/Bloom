import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'ui.dart';

enum ToastVariant { success, error, info }

class ToastItem {
  final String id;
  final String message;
  final ToastVariant variant;
  final DateTime createdAt;

  ToastItem({
    required this.id,
    required this.message,
    required this.variant,
    required this.createdAt,
  });
}

final Signal<List<ToastItem>> toastList = signal<List<ToastItem>>([]);
int _toastIdCounter = 0;

void showToast(String message, [ToastVariant variant = ToastVariant.info]) {
  final id = 'toast_${DateTime.now().millisecondsSinceEpoch}_${++_toastIdCounter}';
  final item = ToastItem(
    id: id,
    message: message,
    variant: variant,
    createdAt: DateTime.now(),
  );
  toastList.value = [...toastList.value, item];

  Timer(const Duration(seconds: 4), () {
    dismissToast(id);
  });
}

void dismissToast(String id) {
  toastList.value = toastList.value.where((t) => t.id != id).toList();
}

BloomNode toastViewport() {
  return Live(() {
    final list = toastList.value;
    if (list.isEmpty) return const Fragment(children: []);

    return Div(
      className: 'fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none px-4 sm:px-0',
      children: list.map((t) => _toastCard(t)).toList(),
    );
  });
}

BloomNode _toastCard(ToastItem item) {
  String bg;
  String fg;
  String border;
  String icon;
  String role;

  switch (item.variant) {
    case ToastVariant.success:
      bg = 'bg-[var(--card)]';
      fg = 'text-[var(--text)]';
      border = 'border-[#16A34A]/40';
      icon = 'check';
      role = 'status';
      break;
    case ToastVariant.error:
      bg = 'bg-[var(--card)]';
      fg = 'text-[var(--text)]';
      border = 'border-[#DC2626]/40';
      icon = 'alert';
      role = 'alert';
      break;
    case ToastVariant.info:
      bg = 'bg-[var(--card)]';
      fg = 'text-[var(--text)]';
      border = 'border-[#0EA5E9]/40';
      icon = 'alert';
      role = 'status';
      break;
  }

  String iconColor;
  switch (item.variant) {
    case ToastVariant.success:
      iconColor = 'text-[#16A34A]';
      break;
    case ToastVariant.error:
      iconColor = 'text-[#DC2626]';
      break;
    case ToastVariant.info:
      iconColor = 'text-[#0EA5E9]';
      break;
  }

  return Div(
    attrs: {
      'role': role,
      'aria-live': item.variant == ToastVariant.error ? 'assertive' : 'polite',
    },
    className: 'pointer-events-auto flex items-center justify-between gap-3 p-3.5 rounded-[10px] border $border $bg $fg shadow-md transition-all duration-200 animate-in fade-in slide-in-from-bottom-2',
    children: [
      Div(
        className: 'flex items-center gap-2.5 min-w-0 flex-1',
        children: [
          Span(className: 'shrink-0 $iconColor', children: [hugeIcon(icon, className: 'w-4 h-4')]),
          Span(className: 'text-sm font-medium leading-snug line-clamp-2', text: item.message),
        ],
      ),
      El('button',
        attrs: {
          'type': 'button',
          'aria-label': 'Dismiss alert',
        },
        className: 'shrink-0 p-1 rounded-md text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[var(--bg-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] transition-colors',
        on: {
          'click': (BloomEvent e) {
            e.preventDefault();
            dismissToast(item.id);
          },
        },
        children: [
          hugeIcon('x', className: 'w-3.5 h-3.5'),
        ],
      ),
    ],
  );
}
