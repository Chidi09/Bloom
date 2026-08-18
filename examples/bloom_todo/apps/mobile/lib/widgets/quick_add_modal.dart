import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../app/boot.dart';

class QuickAddModal extends StatefulWidget {
  final String? defaultProjectId;

  const QuickAddModal({super.key, this.defaultProjectId});

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Priority _priority = Priority.p4;
  DateTime? _dueAt = DateTime.now();
  bool _submitting = false;

  Future<void> _handleSubmit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _submitting = true);

    try {
      await BloomBoot.taskController.createTask(
        title: title,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        projectId: widget.defaultProjectId ?? 'prj_1',
        workspaceId: 'ws_1',
        priority: _priority,
        dueAt: _dueAt,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TodoColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Call Alice tomorrow at 3pm #client',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            style: TodoTypography.bodyMedium,
          ),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              hintText: 'Description',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            style: TodoTypography.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DueDateChip(
                dueAt: _dueAt,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueAt ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _dueAt = picked);
                },
              ),
              const SizedBox(width: 8),
              PrioritySelector(
                selected: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
              const Spacer(),
              IconButton(
                onPressed: _submitting ? null : _handleSubmit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward, color: TodoColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
