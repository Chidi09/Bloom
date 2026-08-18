import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class TaskDetailSheet extends StatefulWidget {
  final Task task;

  const TaskDetailSheet({super.key, required this.task});

  static void show(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskDetailSheet(task: task),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late Priority _priority;
  late String _section;
  late String _projectId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    _priority = widget.task.priority;
    _section = widget.task.sectionId ?? 'In Progress';
    _projectId = widget.task.projectId;
  }

  void _save() {
    final store = TaskStore.instance;
    store.updateTask(
      widget.task.id,
      title: _titleCtrl.text,
      description: _descCtrl.text,
      priority: _priority,
      sectionId: _section,
      projectId: _projectId,
    );
  }

  void _delete() {
    final store = TaskStore.instance;
    store.deleteTask(widget.task.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFF14141A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF27272A))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                BloomCheckbox(
                  checked: widget.task.isCompleted,
                  onChanged: (val) {
                    setState(() {
                      store.toggleTaskComplete(widget.task.id);
                    });
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  widget.task.isCompleted ? 'Completed' : 'Active Task',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.task.isCompleted ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Task',
                  onPressed: _delete,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF71717A)),
                  onPressed: () {
                    _save();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const BloomSeparator(),
            const SizedBox(height: 16),

            // Title & Description Inputs
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => _save(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    onChanged: (_) => _save(),
                    style: const TextStyle(fontSize: 14, color: Color(0xFFA1A1AA)),
                    decoration: const InputDecoration(
                      hintText: 'Add description, notes, or links...',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const BloomSeparator(),
                  const SizedBox(height: 16),

                  // Metadata properties (Priority, Section, Project)
                  Row(
                    children: [
                      const Text('Priority:', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                      const SizedBox(width: 12),
                      PrioritySelector(
                        selected: _priority,
                        onChanged: (p) {
                          setState(() => _priority = p);
                          _save();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Section:', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _section,
                        dropdownColor: const Color(0xFF1E1E24),
                        underline: const SizedBox.shrink(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _section = val);
                            _save();
                          }
                        },
                        items: store.kanbanColumns.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, color: Colors.white)));
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
