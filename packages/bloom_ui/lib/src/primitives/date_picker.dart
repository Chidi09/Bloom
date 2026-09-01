// lib/src/primitives/date_picker.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/bloom_modal_routes.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';
import 'button.dart';
import 'calendar.dart';

/// A date picker trigger button primitive styled with an outline border and calendar icon.
///
/// Tapping the button opens a themed [BloomCalendar] dialog and invokes [onDateSelected] upon confirmation.
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
    final initial = selectedDate ?? now;
    final minDate = firstDate ?? DateTime(2000);
    final maxDate = lastDate ?? DateTime(2100);

    final picked = await showBloomDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Center(
          child: BloomSurface(
            elevation: 8,
            borderRadius: BorderRadius.circular(context.bloomRadius.lg),
            child: Container(
              width: 320,
              padding: EdgeInsets.all(context.bloomSpacing.s4),
              child: BloomCalendar.single(
                selected: initial,
                initialMonth: initial,
                onDaySelected: (day) {
                  if (day.isBefore(minDate) || day.isAfter(maxDate)) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(day);
                },
              ),
            ),
          ),
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
      leftIcon: BloomIcon(BloomIcons.calendar, size: 16, color: colors.textSecondary),
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
