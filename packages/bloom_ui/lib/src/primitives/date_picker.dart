// lib/src/primitives/date_picker.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

/// A date picker trigger button primitive styled with an outline border and calendar icon.
///
/// Tapping the button opens Flutter's themed [showDatePicker] dialog and invokes [onDateSelected] upon confirmation.
///
/// ```dart
/// BloomDatePicker(
///   selectedDate: birthday,
///   placeholder: 'Select birthday',
///   onDateSelected: (date) => setState(() => birthday = date),
/// )
/// ```
class BloomDatePicker extends StatelessWidget {
  /// The currently selected date, formatted as `YYYY-MM-DD` when non-null.
  final DateTime? selectedDate;

  /// Callback invoked when the user confirms a date selection in the dialog.
  final ValueChanged<DateTime> onDateSelected;

  /// The earliest selectable date in the picker dialog.
  ///
  /// Defaults to `DateTime(2000)`.
  final DateTime? firstDate;

  /// The latest selectable date in the picker dialog.
  ///
  /// Defaults to `DateTime(2100)`.
  final DateTime? lastDate;

  /// Placeholder text displayed when [selectedDate] is null.
  ///
  /// Defaults to `'Pick a date'`.
  final String placeholder;

  /// Creates a [BloomDatePicker].
  const BloomDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.placeholder = 'Pick a date',
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.bloomColors.primary,
              surface: context.bloomColors.surface1,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final dateStr = selectedDate != null
        ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
        : placeholder;

    return BloomButton(
      variant: BloomButtonVariant.outline,
      leftIcon: Icon(Icons.calendar_today, size: 16, color: colors.textSecondary),
      onPressed: () => _pickDate(context),
      child: Text(
        dateStr,
        style: TextStyle(
          color: selectedDate != null ? colors.textPrimary : colors.textTertiary,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}
