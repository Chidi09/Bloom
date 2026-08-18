import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../../app/boot.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  @override
  void initState() {
    super.initState();
    BloomBoot.projectController.loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final projects = BloomBoot.projectController.projects.watch(context);
    final loading = BloomBoot.projectController.isLoading.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Projects', style: TodoTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Add project modal
            },
          ),
        ],
      ),
      body: loading && projects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final project = projects[index];
                return ListTile(
                  leading: Text(project.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(project.name, style: TodoTypography.bodyMedium),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => context.go('/projects/${project.id}'),
                );
              },
            ),
    );
  }
}
