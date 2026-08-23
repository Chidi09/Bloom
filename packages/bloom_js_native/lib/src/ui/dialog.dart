import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'button.dart';
import 'icons.dart';

typedef VoidCallback = void Function();

/// Configuration descriptor for a global dialog overlay.
class DialogConfig {
  final String title;
  final String? description;
  final BloomNode? body;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  DialogConfig({
    required this.title,
    this.description,
    this.body,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    this.onConfirm,
    this.onCancel,
  });
}

/// Global active dialog state signal.
final Signal<DialogConfig?> activeDialog = signal<DialogConfig?>(null);

/// Opens a general modal dialog.
void openDialog({
  required String title,
  String? description,
  BloomNode? body,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) {
  activeDialog.value = DialogConfig(
    title: title,
    description: description,
    body: body,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
    onConfirm: onConfirm,
    onCancel: onCancel,
  );
}

/// Helper for standard confirmation dialogs.
void openConfirmDialog({
  required String title,
  String? description,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  required VoidCallback onConfirm,
  VoidCallback? onCancel,
}) {
  openDialog(
    title: title,
    description: description,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
    onConfirm: onConfirm,
    onCancel: onCancel,
  );
}

/// Closes the currently active dialog.
void closeDialog() {
  final cfg = activeDialog.value;
  activeDialog.value = null;
  cfg?.onCancel?.call();
}

/// Root viewport component for rendering the active modal dialog.
///
/// Mount this once near the root of the application.
BloomNode dialogViewport() {
  return Live(() {
    final config = activeDialog.value;
    if (config == null) return const Fragment(children: []);

    final hasFooter = config.confirmLabel != null || config.cancelLabel != null;

    return Div(
      className:
          'fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4',
      onClick: (_) => closeDialog(),
      children: [
        Div(
          attrs: const {
            'role': 'dialog',
            'aria-modal': 'true',
            'aria-labelledby': 'dialog-title',
          },
          className:
              'relative bg-[var(--card)] border border-[var(--border)] rounded-[var(--radius-lg)] '
              'p-6 shadow-[var(--shadow-overlay)] max-w-lg w-full flex flex-col gap-4',
          onClick: (BloomEvent e) => e.stopPropagation(),
          children: [
            // Top close button
            El(
              'button',
              attrs: const {
                'type': 'button',
                'aria-label': 'Close dialog',
              },
              className:
                  'absolute top-4 right-4 text-[var(--text-muted)] hover:text-[var(--text)] '
                  'p-1 rounded-[var(--radius-sm)] transition-colors cursor-pointer',
              onClick: (_) => closeDialog(),
              children: [
                uiIcon('x', className: 'w-4 h-4'),
              ],
            ),
            // Header
            Div(
              className: 'flex flex-col gap-1 pr-6',
              children: [
                H3(
                  attrs: const {'id': 'dialog-title'},
                  className: 'text-lg font-semibold text-[var(--text)] leading-none',
                  text: config.title,
                ),
                if (config.description != null && config.description!.isNotEmpty)
                  P(
                    className: 'text-sm text-[var(--text-muted)] leading-relaxed mt-1',
                    text: config.description!,
                  ),
              ],
            ),
            // Custom body
            if (config.body != null) config.body!,
            // Footer actions
            if (hasFooter)
              Div(
                className: 'flex items-center justify-end gap-3 mt-2 pt-2',
                children: [
                  if (config.cancelLabel != null)
                    button(
                      text: config.cancelLabel!,
                      variant: ButtonVariant.secondary,
                      onClick: (_) => closeDialog(),
                    ),
                  if (config.confirmLabel != null)
                    button(
                      text: config.confirmLabel!,
                      variant: config.destructive
                          ? ButtonVariant.destructive
                          : ButtonVariant.primary,
                      onClick: (_) {
                        final action = config.onConfirm;
                        activeDialog.value = null;
                        action?.call();
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
