import '../framework.dart';
import 'dialog.dart' show VoidCallback;
import 'sheet.dart';

/// Opens a mobile-style bottom drawer (or customizable slide-over).
void openDrawer({
  required String title,
  String? description,
  BloomNode? body,
  String side = 'bottom',
  bool showCloseButton = true,
  VoidCallback? onClose,
}) {
  openSheet(
    title: title,
    description: description,
    body: body,
    side: side,
    showCloseButton: showCloseButton,
    onClose: onClose,
  );
}

/// Closes the currently active drawer.
void closeDrawer() => closeSheet();

/// Viewport component for rendering active drawer/sheet modals.
///
/// Alias for [sheetViewport].
BloomNode drawerViewport() => sheetViewport();
