import 'package:bloom_js_native/bloom_js_native.dart';
import 'button_variants.dart';
import 'ui.dart';

typedef VoidCallback = void Function();

class DialogConfig {
  final String title;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final VoidCallback onConfirm;

  DialogConfig({
    required this.title,
    this.description,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    required this.onConfirm,
  });
}

final Signal<DialogConfig?> activeDialog = signal<DialogConfig?>(null);

void openConfirmDialog({
  required String title,
  String? description,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  required VoidCallback onConfirm,
}) {
  activeDialog.value = DialogConfig(
    title: title,
    description: description,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
    onConfirm: onConfirm,
  );
}

void closeDialog() {
  activeDialog.value = null;
}

BloomNode dialogViewport() {
  return Live(() {
    final config = activeDialog.value;
    if (config == null) return const Fragment(children: []);

    return Div(
      className: 'fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4',
      onClick: (_) => closeDialog(),
      children: [
        Div(
          attrs: {
            'role': 'dialog',
            'aria-modal': 'true',
            'aria-labelledby': 'dialog-title',
          },
          className: 'bg-[var(--card)] border border-[var(--border)] rounded-[var(--radius-lg)] p-6 shadow-[var(--shadow-overlay)] max-w-md w-full',
          onClick: (BloomEvent e) => e.stopPropagation(),
          children: [
            H3(
              attrs: {'id': 'dialog-title'},
              className: 'text-h3 font-semibold text-[var(--text)] mb-2',
              text: config.title,
            ),
            if (config.description != null && config.description!.isNotEmpty)
              P(
                className: 'text-sm text-[var(--text-muted)] leading-relaxed mb-6',
                text: config.description!,
              ),
            Div(
              className: 'flex items-center justify-end gap-3 mt-6',
              children: [
                button(
                  text: config.cancelLabel,
                  variant: ButtonVariant.secondary,
                  onClick: (_) => closeDialog(),
                ),
                button(
                  text: config.confirmLabel,
                  variant: config.destructive ? ButtonVariant.destructive : ButtonVariant.primary,
                  onClick: (_) {
                    config.onConfirm();
                    closeDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  });
}
