import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class QuickAddDialog extends StatefulWidget {
  final String? defaultProjectId;

  const QuickAddDialog({super.key, this.defaultProjectId});

  static void show(BuildContext context, {String? defaultProjectId}) {
    showDialog(
      context: context,
      builder: (context) => QuickAddDialog(defaultProjectId: defaultProjectId),
    );
  }

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String _selectedProjectId;
  Priority _priority = Priority.p2;
  DateTime _dueAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final store = TaskStore.instance;
    _selectedProjectId = widget.defaultProjectId ?? store.projects.first.id;
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final store = TaskStore.instance;
    final labels = <String>[];

    // Simple NLP Tag extraction
    final words = title.split(' ');
    for (final word in words) {
      if (word.startsWith('@') && word.length > 1) {
        labels.add(word.substring(1));
      }
    }

    store.createTask(
      title: title,
      description: _descCtrl.text.trim(),
      projectId: _selectedProjectId,
      priority: _priority,
      dueAt: _dueAt,
      labels: labels,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: BloomCard(
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF27272A),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF71717A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title Input
                TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Optimize AOT isolate memory pool @backend',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFF71717A)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),

                // Description Input
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
                  decoration: const InputDecoration(
                    hintText: 'Description or acceptance criteria (optional)',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF52525B)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                const BloomSeparator(),
                const SizedBox(height: 16),

                // Selectors (Priority, Project, Date)
                Row(
                  children: [
                    // Priority Flags
                    PrioritySelector(
                      selected: _priority,
                      onChanged: (p) => setState(() => _priority = p),
                    ),
                    const SizedBox(width: 12),

                    // Project Dropdown
                    DropdownButton<String>(
                      value: _selectedProjectId,
                      dropdownColor: const Color(0xFF1E1E24),
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF71717A)),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProjectId = val);
                      },
                      items: store.projects.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _parseColor(p.colorHex))),
                              const SizedBox(width: 8),
                              Text(p.name, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const Spacer(),

                    // Submit Button
                    BloomButton(
                      size: BloomButtonSize.sm,
                      onPressed: _submit,
                      child: const Text('Add Task'),
                    ),
                  ],
                ),
              ],
            ),
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
