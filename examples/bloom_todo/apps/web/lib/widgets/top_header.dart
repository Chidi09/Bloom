import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'quick_add_dialog.dart';

class TopHeaderView extends StatelessWidget {
  final int activeNav;
  final String selectedProjectId;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const TopHeaderView({
    super.key,
    required this.activeNav,
    required this.selectedProjectId,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final currentProject = store.getProject(selectedProjectId);
    final activeTitle = switch (activeNav) {
      0 => 'Today Focus',
      1 => currentProject.name,
      2 => 'Upcoming Timeline',
      3 => 'Inbox Triage',
      4 => 'Live Team Activity',
      _ => 'Dashboard',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF09090B),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E24))),
      ),
      child: Row(
        children: [
          Text(
            activeTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
          ),
          const SizedBox(width: 16),

          // Filters
          Row(
            children: [
              _buildFilterChip('all', 'All Tasks'),
              const SizedBox(width: 6),
              _buildFilterChip('p1', 'P1 Urgent'),
              const SizedBox(width: 6),
              _buildFilterChip('my_tasks', 'Assigned to Me'),
            ],
          ),

          const Spacer(),

          // Cluster Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text('Cluster Sync Active (8 Isolates)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // New Task Button
          BloomButton(
            size: BloomButtonSize.sm,
            onPressed: () => QuickAddDialog.show(context, defaultProjectId: selectedProjectId),
            child: const Row(
              children: [
                Icon(Icons.add_rounded, size: 14),
                SizedBox(width: 4),
                Text('New Task'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = selectedFilter == id;
    return InkWell(
      onTap: () => onFilterChanged(id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }
}
