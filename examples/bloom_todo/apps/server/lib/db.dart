import 'package:bloom_todo_core/core.dart';

/// Centralized database store for Bloom Todo server.
/// Seeds real workspace, project, and task data on startup and supports full CRUD.
class ServerDb {
  static final ServerDb instance = ServerDb._internal();
  factory ServerDb() => instance;

  ServerDb._internal() {
    _seed();
  }

  final List<Workspace> workspaces = [];
  final List<Project> projects = [];
  final List<Task> tasks = [];
  final List<Section> sections = [];

  void _seed() {
    final now = DateTime.now();

    // 1. Seed Workspaces
    workspaces.addAll([
      Workspace(
        id: 'ws_1',
        name: 'Acme Corp',
        slug: 'acme-corp',
        ownerId: 'usr_demo_123',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
      Workspace(
        id: 'ws_2',
        name: 'Personal Space',
        slug: 'personal',
        ownerId: 'usr_demo_123',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      ),
    ]);

    // 2. Seed Projects
    projects.addAll([
      Project(
        id: 'prj_1',
        workspaceId: 'ws_1',
        name: 'Bloom Framework Core',
        colorHex: '#6366F1',
        icon: 'hub_outlined',
        position: 0,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
      Project(
        id: 'prj_2',
        workspaceId: 'ws_1',
        name: 'Mobile Client (Flutter)',
        colorHex: '#10B981',
        icon: 'phone_android_outlined',
        position: 1,
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now,
      ),
      Project(
        id: 'prj_3',
        workspaceId: 'ws_1',
        name: 'Cloud & Cluster Engine',
        colorHex: '#0EA5E9',
        icon: 'bolt_outlined',
        position: 2,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now,
      ),
      Project(
        id: 'prj_4',
        workspaceId: 'ws_1',
        name: 'Design System & Bloom UI',
        colorHex: '#8B5CF6',
        icon: 'palette_outlined',
        position: 3,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      ),
      Project(
        id: 'prj_5',
        workspaceId: 'ws_1',
        name: 'Q3 Launch & Architecture',
        colorHex: '#F59E0B',
        icon: 'layers_outlined',
        position: 4,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
    ]);

    // 3. Seed Sections
    sections.addAll([
      Section(id: 'sec_1', projectId: 'prj_1', name: 'Backlog', position: 0, createdAt: now),
      Section(id: 'sec_2', projectId: 'prj_1', name: 'In Progress', position: 1, createdAt: now),
      Section(id: 'sec_3', projectId: 'prj_1', name: 'In Review', position: 2, createdAt: now),
      Section(id: 'sec_4', projectId: 'prj_1', name: 'Done', position: 3, createdAt: now),
    ]);

    // 4. Seed Tasks
    tasks.addAll([
      Task(
        id: 'tsk_101',
        projectId: 'prj_1',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Complete Bloom multi-isolate cluster benchmarks',
        description: 'Profile throughput across 8 isolates under 10k concurrent WebSockets in AOT mode',
        priority: Priority.p1,
        dueAt: now,
        position: 0,
        isCompleted: false,
        labels: ['benchmark', 'isolate'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_102',
        projectId: 'prj_1',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Optimize SQLite WAL mode connection pool',
        description: 'Enforce synchronous=NORMAL and mmap_size for zero disk thrashing',
        priority: Priority.p1,
        dueAt: now,
        position: 1,
        isCompleted: false,
        labels: ['db', 'crdt'],
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_103',
        projectId: 'prj_2',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Implement offline mutation queue replay on resume',
        description: 'Replay batched delta operations deterministically with field-level resolution',
        priority: Priority.p2,
        dueAt: now,
        position: 2,
        isCompleted: true,
        labels: ['mobile', 'offline'],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_104',
        projectId: 'prj_4',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Export native Bloom UI dashboard primitives',
        description: 'Ship BloomCard, BloomBadge, BloomProgress, BloomKbd and BloomTabs',
        priority: Priority.p2,
        dueAt: now.subtract(const Duration(days: 1)),
        position: 3,
        isCompleted: true,
        labels: ['ui', 'primitives'],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_105',
        projectId: 'prj_3',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Setup Shorebird OTA automatic crash circuit breaker',
        description: 'Trigger instant rollback if app crashes within 10s of booting patch',
        priority: Priority.p1,
        dueAt: now.add(const Duration(days: 1)),
        position: 4,
        isCompleted: false,
        labels: ['ota', 'devops'],
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_106',
        projectId: 'prj_1',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'RFC 5545 Recurrence Parser unit test coverage',
        description: 'Verify DAILY, WEEKLY BYDAY and MONTHLY BYSETPOS RRULE matrices',
        priority: Priority.p3,
        dueAt: now.add(const Duration(days: 1)),
        position: 5,
        isCompleted: false,
        labels: ['rrule', 'testing'],
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now,
      ),
      Task(
        id: 'tsk_107',
        projectId: 'prj_5',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Prepare Vercel-grade interactive documentation',
        description: 'Include live typewriter code runner and CLI snippet copy button',
        priority: Priority.p2,
        dueAt: now.add(const Duration(days: 3)),
        position: 6,
        isCompleted: false,
        labels: ['docs', 'launch'],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  List<Task> listTasks({String? workspaceId, String? projectId}) {
    var result = tasks;
    if (workspaceId != null) {
      result = result.where((t) => t.workspaceId == workspaceId).toList();
    }
    if (projectId != null) {
      result = result.where((t) => t.projectId == projectId).toList();
    }
    return result;
  }

  Task? getTask(String id) {
    try {
      return tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Task createTask({
    required String projectId,
    required String workspaceId,
    required String title,
    String? description,
    Priority priority = Priority.p2,
    DateTime? dueAt,
    List<String> labels = const [],
  }) {
    final now = DateTime.now();
    final newTask = Task(
      id: 'tsk_${now.millisecondsSinceEpoch}',
      projectId: projectId,
      workspaceId: workspaceId,
      creatorId: 'usr_demo_123',
      title: title,
      description: description,
      priority: priority,
      dueAt: dueAt ?? now,
      position: tasks.length,
      isCompleted: false,
      labels: labels,
      createdAt: now,
      updatedAt: now,
    );
    tasks.insert(0, newTask);
    return newTask;
  }

  Task? toggleTaskComplete(String id) {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = tasks[index];
      final updated = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now().toUtc() : null,
        updatedAt: DateTime.now().toUtc(),
      );
      tasks[index] = updated;
      return updated;
    }
    return null;
  }

  bool deleteTask(String id) {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      tasks.removeAt(index);
      return true;
    }
    return false;
  }

  List<Project> listProjects({String? workspaceId}) {
    if (workspaceId != null) {
      return projects.where((p) => p.workspaceId == workspaceId).toList();
    }
    return projects;
  }

  List<Workspace> listWorkspaces() => workspaces;
}
