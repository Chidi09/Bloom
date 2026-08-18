import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';

class WorkspaceSettingsPage extends StatelessWidget {
  const WorkspaceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workspace Settings', style: TodoTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('General', style: TodoTypography.h3),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: 'Workspace Name'),
          ),
          const SizedBox(height: 32),
          Text('Members & Permissions', style: TodoTypography.h3),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(child: Text('A')),
            title: const Text('Alex Rivers (Owner)'),
            subtitle: const Text('alex@bloomtodo.dev'),
            trailing: const Chip(label: Text('Owner')),
          ),
        ],
      ),
    );
  }
}
