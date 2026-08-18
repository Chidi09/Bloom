import 'package:signals/signals.dart';
import 'package:bloom_todo_core/core.dart';
import '../repositories/project_repository.dart';

class ProjectController {
  final ProjectRepository repository;

  final projects = signal<List<Project>>([]);
  final selectedProject = signal<Project?>(null);
  final isLoading = signal(false);

  ProjectController(this.repository);

  Future<void> loadProjects({String? workspaceId}) async {
    isLoading.value = true;
    try {
      projects.value = await repository.list(workspaceId: workspaceId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createProject({
    required String name,
    required String workspaceId,
    String? colorHex,
    String? icon,
  }) async {
    final prj = await repository.create(
      name: name,
      workspaceId: workspaceId,
      colorHex: colorHex,
      icon: icon,
    );
    projects.value = [...projects.value, prj];
  }
}
