import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';
import 'package:bloom_todo_core/core.dart';
import '../tokens/colors.dart';

class PrioritySelector extends StatelessWidget {
  final Priority selected;
  final ValueChanged<Priority> onChanged;

  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  Color _getColor(Priority p) => switch (p) {
    Priority.p1 => TodoColors.p1,
    Priority.p2 => TodoColors.p2,
    Priority.p3 => TodoColors.p3,
    Priority.p4 => TodoColors.p4,
  };

  String _getLabel(Priority p) => switch (p) {
    Priority.p1 => 'P1',
    Priority.p2 => 'P2',
    Priority.p3 => 'P3',
    Priority.p4 => 'P4',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: Priority.values.map((p) {
        final isSelected = selected == p;
        final color = _getColor(p);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () => onChanged(p),
            borderRadius: BorderRadius.circular(6),
            child: BloomBadge(
              variant: isSelected
                  ? (p == Priority.p1
                      ? BloomBadgeVariant.destructive
                      : BloomBadgeVariant.defaultVariant)
                  : BloomBadgeVariant.outline,
              size: BloomBadgeSize.defaultSize,
              leading: Icon(Icons.flag, size: 12, color: isSelected ? Colors.white : color),
              child: Text(_getLabel(p)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
