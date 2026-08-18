import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class DueDateChip extends StatelessWidget {
  final DateTime? dueAt;
  final String? recurrenceRule;
  final VoidCallback? onTap;

  const DueDateChip({
    super.key,
    required this.dueAt,
    this.recurrenceRule,
    this.onTap,
  });

  bool get isOverdue {
    if (dueAt == null) return false;
    final now = DateTime.now();
    return dueAt!.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    return dueAt!.year == now.year &&
        dueAt!.month == now.month &&
        dueAt!.day == now.day;
  }

  bool get isTomorrow {
    if (dueAt == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dueAt!.year == tomorrow.year &&
        dueAt!.month == tomorrow.month &&
        dueAt!.day == tomorrow.day;
  }

  String get formattedText {
    if (dueAt == null) return 'No due date';
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    return '${dueAt!.day}/${dueAt!.month}';
  }

  BloomBadgeVariant get badgeVariant {
    if (isOverdue) return BloomBadgeVariant.destructive;
    if (isToday) return BloomBadgeVariant.success;
    return BloomBadgeVariant.outline;
  }

  @override
  Widget build(BuildContext context) {
    return BloomBadge(
      variant: badgeVariant,
      size: BloomBadgeSize.sm,
      leading: const Icon(Icons.calendar_today, size: 10),
      trailing: recurrenceRule != null ? const Icon(Icons.repeat, size: 10) : null,
      onTap: onTap,
      child: Text(formattedText),
    );
  }
}
