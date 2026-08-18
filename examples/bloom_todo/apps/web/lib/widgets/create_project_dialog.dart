import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateProjectDialog(),
    );
  }

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameCtrl = TextEditingController();
  Color _selectedColor = const Color(0xFF6366F1);
  String _selectedIcon = 'folder_outlined';

  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFF0EA5E9), // Sky
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  static const List<(String, IconData)> _icons = [
    ('folder_outlined', Icons.folder_outlined),
    ('hub_outlined', Icons.hub_outlined),
    ('layers_outlined', Icons.layers_outlined),
    ('bolt_outlined', Icons.bolt_outlined),
    ('code_outlined', Icons.code_outlined),
    ('memory_outlined', Icons.memory_outlined),
    ('shield_outlined', Icons.shield_outlined),
    ('phone_android_outlined', Icons.phone_android_outlined),
  ];

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final hex = '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    TaskStore.instance.createProject(
      name: name,
      colorHex: hex,
      icon: _selectedIcon,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: BloomCard(
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF27272A),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create New Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF71717A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name Input
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g. Infrastructure 2.0',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Color Palette
                const Text('Color Palette', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA))),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _palette.map((color) {
                    final isSelected = _selectedColor == color;
                    return InkWell(
                      onTap: () => setState(() => _selectedColor = color),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Vector Icon Picker
                const Text('Vector Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA))),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _icons.map((item) {
                    final (id, icon) = item;
                    final isSelected = _selectedIcon == id;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.transparent),
                        ),
                        child: Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFFA1A1AA)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Submit Button
                BloomButton(
                  size: BloomButtonSize.lg,
                  onPressed: _submit,
                  child: const Text('Create Project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
