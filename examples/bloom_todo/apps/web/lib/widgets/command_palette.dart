import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class CommandPalette extends StatefulWidget {
  final Function(String projectId)? onSelectProject;
  final Function(int navIndex)? onNavigate;
  final VoidCallback? onOpenQuickAdd;

  const CommandPalette({
    super.key,
    this.onSelectProject,
    this.onNavigate,
    this.onOpenQuickAdd,
  });

  static void show(
    BuildContext context, {
    Function(String projectId)? onSelectProject,
    Function(int navIndex)? onNavigate,
    VoidCallback? onOpenQuickAdd,
  }) {
    showDialog(
      context: context,
      builder: (context) => CommandPalette(
        onSelectProject: onSelectProject,
        onNavigate: onNavigate,
        onOpenQuickAdd: onOpenQuickAdd,
      ),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final matchingProjects = store.projects
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final matchingTasks = store.tasks
        .where((t) =>
            t.title.toLowerCase().contains(_query.toLowerCase()) ||
            t.labels.any((l) => l.toLowerCase().contains(_query.toLowerCase())))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        child: BloomCard(
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF27272A),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (val) => setState(() => _query = val),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a command, task, or search projects...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF71717A)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const BloomKbd(text: 'ESC'),
                      ),
                    ),
                  ),
                ),
              ),
              const BloomSeparator(),

              // Search Results List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // System Actions
                    if (_query.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'ACTIONS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF71717A)),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 18),
                        title: const Text('Create new task', style: TextStyle(fontSize: 13, color: Colors.white)),
                        trailing: const BloomKbd(text: 'Q'),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenQuickAdd?.call();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF59E0B), size: 18),
                        title: const Text('Jump to Today view', style: TextStyle(fontSize: 13, color: Colors.white)),
                        trailing: const BloomKbd(text: '1'),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate?.call(0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.view_kanban_outlined, color: Color(0xFF10B981), size: 18),
                        title: const Text('Open Project Kanban board', style: TextStyle(fontSize: 13, color: Colors.white)),
                        trailing: const BloomKbd(text: '2'),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigate?.call(1);
                        },
                      ),
                      const SizedBox(height: 8),
                      const BloomSeparator(),
                    ],

                    // Matching Projects
                    if (matchingProjects.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'PROJECTS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF71717A)),
                        ),
                      ),
                      ...matchingProjects.map((p) => ListTile(
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _parseColor(p.colorHex)),
                            ),
                            title: Text(p.name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                            trailing: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF71717A)),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectProject?.call(p.id);
                            },
                          )),
                      const SizedBox(height: 8),
                      const BloomSeparator(),
                    ],

                    // Matching Tasks
                    if (matchingTasks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'TASKS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF71717A)),
                        ),
                      ),
                      ...matchingTasks.map((t) => ListTile(
                            leading: Icon(
                              t.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: t.isCompleted ? const Color(0xFF10B981) : const Color(0xFF71717A),
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                color: t.isCompleted ? const Color(0xFF71717A) : Colors.white,
                              ),
                            ),
                            trailing: BloomBadge(
                              variant: BloomBadgeVariant.outline,
                              size: BloomBadgeSize.sm,
                              child: Text(t.sectionId ?? 'In Progress'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              store.toggleTaskComplete(t.id);
                            },
                          )),
                    ],

                    if (_query.isNotEmpty && matchingProjects.isEmpty && matchingTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No matching tasks or projects found', style: TextStyle(color: Color(0xFF71717A), fontSize: 13)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
