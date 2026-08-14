// lib/src/primitives/date_picker.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

class BloomDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String placeholder;

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
