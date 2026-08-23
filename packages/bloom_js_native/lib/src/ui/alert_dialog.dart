import '../framework.dart';
import 'dialog.dart';

/// Opens an alert confirmation dialog (destructive action confirmation).
void openAlertDialog({
  required String title,
  String? description,
  BloomNode? body,
  String confirmLabel = 'Continue',
  String cancelLabel = 'Cancel',
  bool destructive = true,
  required VoidCallback onConfirm,
  VoidCallback? onCancel,
}) {
  openDialog(
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
