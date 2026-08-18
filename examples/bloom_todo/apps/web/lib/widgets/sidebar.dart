import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'create_project_dialog.dart';
import 'workspace_settings_dialog.dart';

class SidebarView extends StatelessWidget {
  final int activeNav;
  final String selectedProjectId;
  final ValueChanged<int> onNavChanged;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onOpenCommandPalette;

  const SidebarView({
    super.key,
    required this.activeNav,
    required this.selectedProjectId,
    required this.onNavChanged,
    required this.onProjectSelected,
    required this.onOpenCommandPalette,
  });

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E12),
        border: Border(right: BorderSide(color: Color(0xFF1E1E24))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workspace Switcher
          InkWell(
            onTap: () => WorkspaceSettingsDialog.show(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('A', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.currentWorkspace.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        const Text('Pro Team • 8 Isolates', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF71717A)),
                ],
              ),
            ),
          ),

          // Search / Command Trigger
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: InkWell(
              onTap: onOpenCommandPalette,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF22222A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, size: 15, color: Color(0xFF71717A)),
                    SizedBox(width: 8),
                    Text('Search or Jump to...', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                    Spacer(),
                    BloomKbd(text: '⌘K'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const BloomSeparator(),
          const SizedBox(height: 8),

          // Nav Items
          _buildNavItem(0, Icons.wb_sunny_outlined, 'Today', '${store.pendingTodayCount}'),
          _buildNavItem(1, Icons.view_kanban_outlined, 'Project Board', '${store.tasks.where((t) => !t.isCompleted).length}'),
          _buildNavItem(2, Icons.calendar_month_outlined, 'Upcoming', '${store.upcomingCount}'),
          _buildNavItem(3, Icons.inbox_outlined, 'Inbox', '${store.inboxCount}'),
          _buildNavItem(4, Icons.bolt_outlined, 'Live Activity', '${store.activities.length}'),

          const SizedBox(height: 16),
          const BloomSeparator(),

          // Projects Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PROJECTS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF71717A)),
                ),
                InkWell(
                  onTap: () => CreateProjectDialog.show(context),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.add_rounded, size: 16, color: Color(0xFFA1A1AA)),
                  ),
                ),
              ],
            ),
          ),

          // Project List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: store.projects.map((p) {
                final isSelected = selectedProjectId == p.id && activeNav == 1;
                final count = store.tasks.where((t) => t.projectId == p.id && !t.isCompleted).length;
                final color = _parseColor(p.colorHex);

                return InkWell(
                  onTap: () => onProjectSelected(p.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E1E24) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                            ),
                          ),
                        ),
                        Text('$count', style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // User Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF111116),
              border: Border(top: BorderSide(color: Color(0xFF1E1E24))),
            ),
            child: Row(
              children: [
                const BloomAvatar(name: 'Alex Rivers', size: BloomAvatarSize.sm),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alex Rivers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('alex@bloomtodo.dev', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF71717A)),
                  onPressed: () => WorkspaceSettingsDialog.show(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, String count) {
    final isSelected = activeNav == index;
    return InkWell(
      onTap: () => onNavChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E24) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF71717A)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
              ),
            ),
            const Spacer(),
            if (count != '0')
              BloomBadge(
                variant: isSelected ? BloomBadgeVariant.defaultVariant : BloomBadgeVariant.outline,
                size: BloomBadgeSize.sm,
                child: Text(count),
              ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null) return const Color(0xFF6366F1);
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return const Color(0xFF6366F1);
  }
}
