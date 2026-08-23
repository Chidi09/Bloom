import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'dialog.dart' show VoidCallback;
import 'icons.dart';

/// Configuration descriptor for slide-over side panels and drawers.
class SheetConfig {
  final String title;
  final String? description;
  final BloomNode? body;
  final String side; // 'right' | 'left' | 'top' | 'bottom'
  final bool showCloseButton;
  final VoidCallback? onClose;

  SheetConfig({
    required this.title,
    this.description,
    this.body,
    this.side = 'right',
    this.showCloseButton = true,
    this.onClose,
  });
}

/// Global active sheet / drawer state signal.
final Signal<SheetConfig?> activeSheet = signal<SheetConfig?>(null);

/// Opens a side-panel sheet.
void openSheet({
  required String title,
  String? description,
  BloomNode? body,
  String side = 'right',
  bool showCloseButton = true,
  VoidCallback? onClose,
}) {
  activeSheet.value = SheetConfig(
    title: title,
    description: description,
    body: body,
    side: side,
    showCloseButton: showCloseButton,
    onClose: onClose,
  );
}

/// Closes the currently active sheet / drawer.
void closeSheet() {
  final cfg = activeSheet.value;
  activeSheet.value = null;
  cfg?.onClose?.call();
}

/// Root viewport component for rendering active slide-over sheets and bottom drawers.
///
/// Mount this once near the root of the application.
BloomNode sheetViewport() {
  return Live(() {
    final config = activeSheet.value;
    if (config == null) return const Fragment(children: []);

    final side = config.side;

    final sideClasses = switch (side) {
      'left' =>
        'inset-y-0 left-0 h-full w-3/4 max-w-sm border-r border-[var(--border)]',
      'top' => 'inset-x-0 top-0 w-full border-b border-[var(--border)]',
      'bottom' =>
        'inset-x-0 bottom-0 w-full max-h-[85vh] rounded-t-[var(--radius-lg)] border-t border-[var(--border)]',
      _ =>
        'inset-y-0 right-0 h-full w-3/4 max-w-sm border-l border-[var(--border)]',
    };

    return Div(
      className: 'fixed inset-0 bg-black/60 backdrop-blur-sm z-50 select-none',
      onClick: (_) => closeSheet(),
      children: [
        Div(
          attrs: const {
            'role': 'dialog',
            'aria-modal': 'true',
          },
          className: cn([
            'fixed bg-[var(--card)] p-6 shadow-[var(--shadow-overlay)] flex flex-col gap-4 z-50 overflow-y-auto select-text',
            sideClasses,
          ]),
          onClick: (BloomEvent e) => e.stopPropagation(),
          children: [
            // Drawer handle indicator on bottom sheet
            if (side == 'bottom')
              Div(
                className: 'mx-auto -mt-2 mb-2 h-1 w-12 rounded-full bg-[var(--border)]',
              ),
            // Header
            Div(
              className: 'flex items-start justify-between gap-4',
              children: [
                Div(
                  className: 'flex flex-col gap-1',
                  children: [
                    H3(
                      className:
                          'text-base font-semibold text-[var(--text)] leading-tight',
                      text: config.title,
                    ),
                    if (config.description != null &&
                        config.description!.isNotEmpty)
                      P(
                        className: 'text-xs text-[var(--text-muted)] leading-relaxed',
                        text: config.description!,
                      ),
                  ],
                ),
                if (config.showCloseButton)
                  El(
                    'button',
                    attrs: const {
                      'type': 'button',
                      'aria-label': 'Close panel',
                    },
                    className:
                        'text-[var(--text-muted)] hover:text-[var(--text)] p-1 rounded-[var(--radius-sm)] transition-colors cursor-pointer',
                    onClick: (_) => closeSheet(),
                    children: [uiIcon('x', className: 'w-4 h-4')],
                  ),
              ],
            ),
            // Custom body
            if (config.body != null) config.body!,
          ],
        ),
      ],
    );
  });
}
