import 'package:bloom_js_native/bloom_js_native.dart';
import 'toast_bridge_stub.dart'
    if (dart.library.html) 'toast_bridge_web.dart';
import 'huge_icons.dart';

class ToastData {
  final String id;
  final String title;
  final String message;
  final String type;

  ToastData({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'purple',
  });
}

final activeToasts = signal<List<ToastData>>([]);

void showToast(String title, String message, {String type = 'purple'}) {
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final toast = ToastData(id: id, title: title, message: message, type: type);
  activeToasts.value = [...activeToasts.value, toast];
}

void removeToast(String id) {
  activeToasts.value = activeToasts.value.where((t) => t.id != id).toList();
}

BloomNode siteToastViewport() {
  ensureToastEventBridge();
  return Div(
    attrs: const {'id': 'bloom-toast-container'},
    className:
        'fixed bottom-6 right-6 z-[110] flex flex-col gap-2 '
        'pointer-events-none max-w-sm w-full px-4',
    children: [
      Live(() {
        final toasts = activeToasts.value;
        return Fragment(
          children: [
            for (final toast in toasts)
              Div(
                attrs: {'id': 'toast-${toast.id}'},
                className:
                    'glass-panel border-l-4 ${toast.type == 'emerald'
                        ? 'border-emerald-500'
                        : toast.type == 'blue'
                        ? 'border-blue-500'
                        : 'border-purple-500'} border-y border-r shadow-2xl rounded-2xl p-4 transform transition-all duration-300 pointer-events-auto flex gap-3 items-start relative animate-in fade-in slide-in-from-bottom-5',
                children: [
                  hugeIcon(
                    toast.type == 'emerald'
                        ? 'check-circle'
                        : toast.type == 'blue'
                        ? 'info'
                        : 'zap',
                    className:
                        'w-5 h-5 ${toast.type == 'emerald'
                            ? 'text-emerald-500'
                            : toast.type == 'blue'
                            ? 'text-blue-500'
                            : 'text-purple-500'} shrink-0',
                  ),
                  Div(
                    className: 'flex-1 min-w-0 pr-6',
                    children: [
                      H4(
                        className:
                            'text-sm font-bold ${toast.type == 'emerald'
                                ? 'text-emerald-700 dark:text-emerald-300'
                                : toast.type == 'blue'
                                ? 'text-blue-700 dark:text-blue-300'
                                : 'text-purple-700 dark:text-purple-300'}',
                        text: toast.title,
                      ),
                      P(
                        className:
                            'text-xs text-slate-600 dark:text-slate-400 mt-1 '
                            'leading-relaxed',
                        text: toast.message,
                      ),
                    ],
                  ),
                  Button(
                    attrs: const {
                      'type': 'button',
                      'aria-label': 'Close notification',
                    },
                    onClick: (_) => removeToast(toast.id),
                    className:
                        'absolute top-3 right-3 text-slate-400 '
                        'hover:text-slate-600 dark:hover:text-slate-200',
                    children: [hugeIcon('x', className: 'w-4 h-4')],
                  ),
                ],
              ),
          ],
        );
      }),
    ],
  );
}
