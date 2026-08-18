import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';
import 'package:bloom_todo_core/core.dart';

class ProjectChip extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;

  const ProjectChip({
    super.key,
    required this.project,
    this.onTap,
  });

  Color get _color {
    final hex = project.colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return BloomBadge(
      variant: BloomBadgeVariant.outline,
      size: BloomBadgeSize.sm,
      leading: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
        ),
      ),
      onTap: onTap,
      child: Text(project.name),
    );
  }
}
