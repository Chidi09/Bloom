import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';

/// Centralized reactive state store for Bloom Todo Web.
/// Adheres to Single Responsibility (SRP) and DRY by reusing core domain models.
class TaskStore extends ChangeNotifier {
  static final TaskStore instance = TaskStore._internal();
  factory TaskStore() => instance;

  TaskStore._internal() {
    _seedInitialData();
  }

  final List<Workspace> workspaces = [];
  final List<Project> projects = [];
  final List<Task> tasks = [];
  final List<ActivityEvent> activities = [];
  final List<String> kanbanColumns = ['Backlog', 'In Progress', 'In Review', 'Done'];

  int karmaScore = 1450;
  int dailyGoal = 6;
  String currentWorkspaceId = 'ws_1';

  void _seedInitialData() {
    final now = DateTime.now();

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

    tasks.addAll([
      Task(
        id: 'tsk_101',
        projectId: 'prj_1',
        workspaceId: 'ws_1',
        creatorId: 'usr_demo_123',
        title: 'Complete Bloom multi-isolate cluster benchmarks',
        description: 'Profile throughput across 8 isolates under 10,000 concurrent WebSockets in AOT mode.',
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
        description: 'Enforce synchronous=NORMAL and mmap_size for zero disk thrashing under high write volume.',
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
        description: 'Replay batched delta operations deterministically with field-level resolution.',
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
        description: 'Ship BloomCard, BloomBadge, BloomProgress, BloomKbd and BloomTabs.',
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
        description: 'Trigger instant rollback if app crashes within 10s of booting a hot patch.',
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
        description: 'Verify DAILY, WEEKLY BYDAY and MONTHLY BYSETPOS RRULE matrices.',
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
        description: 'Include live typewriter code runner and CLI snippet copy button.',
        priority: Priority.p2,
        dueAt: now.add(const Duration(days: 3)),
        position: 6,
        isCompleted: false,
        labels: ['docs', 'launch'],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      ),
    ]);

    activities.addAll([
      ActivityEvent(
        id: 'act_1',
        taskId: 'tsk_101',
        workspaceId: 'ws_1',
        actorId: 'usr_elena',
        type: EventType.taskCompleted,
        body: 'Elena completed task: Multi-isolate cluster telemetry',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      ActivityEvent(
        id: 'act_2',
        taskId: 'tsk_106',
        workspaceId: 'ws_1',
        actorId: 'usr_david',
        type: EventType.taskUpdated,
        body: 'David moved task to In Review: RFC 5545 recurrence parser',
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      ActivityEvent(
        id: 'act_3',
        taskId: 'tsk_104',
        workspaceId: 'ws_1',
        actorId: 'usr_sarah',
        type: EventType.taskCreated,
        body: 'Sarah pushed patch: Bloom UI design tokens v0.2.3',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Reactive Actions
  // ---------------------------------------------------------------------------

  void toggleTaskComplete(String taskId) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = tasks[index];
      final newCompleted = !task.isCompleted;
      tasks[index] = task.copyWith(
        isCompleted: newCompleted,
        completedAt: newCompleted ? DateTime.now().toUtc() : null,
        updatedAt: DateTime.now().toUtc(),
      );
      karmaScore += newCompleted ? 25 : -25;
      logActivity(
        newCompleted ? EventType.taskCompleted : EventType.taskUpdated,
        newCompleted ? 'completed task: ${task.title}' : 'uncompleted task: ${task.title}',
      );
      notifyListeners();
    }
  }

  void createTask({
    required String title,
    String? description,
    required String projectId,
    Priority priority = Priority.p2,
    DateTime? dueAt,
    List<String> labels = const [],
    String? sectionId,
  }) {
    final now = DateTime.now();
    final newTask = Task(
      id: 'tsk_${now.millisecondsSinceEpoch}',
      projectId: projectId,
      workspaceId: currentWorkspaceId,
      creatorId: 'usr_demo_123',
      sectionId: sectionId,
      title: title.trim(),
      description: description?.trim(),
      priority: priority,
      dueAt: dueAt ?? now,
      position: tasks.length,
      isCompleted: false,
      labels: labels,
      createdAt: now,
      updatedAt: now,
    );

    tasks.insert(0, newTask);
    karmaScore += 10;
    logActivity(EventType.taskCreated, 'created task: ${newTask.title}');
    notifyListeners();
  }

  void updateTask(
    String taskId, {
    String? title,
    String? description,
    Priority? priority,
    DateTime? dueAt,
    String? projectId,
    String? sectionId,
    List<String>? labels,
  }) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = tasks[index];
      tasks[index] = task.copyWith(
        title: title?.trim(),
        description: description?.trim(),
        priority: priority,
        dueAt: dueAt,
        projectId: projectId,
        sectionId: sectionId,
        labels: labels,
        updatedAt: DateTime.now().toUtc(),
      );
      logActivity(EventType.taskUpdated, 'updated task: ${tasks[index].title}');
      notifyListeners();
    }
  }

  void deleteTask(String taskId) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final title = tasks[index].title;
      tasks.removeAt(index);
      logActivity(EventType.taskUpdated, 'deleted task: $title');
      notifyListeners();
    }
  }

  void moveTaskSection(String taskId, String newSection) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = tasks[index];
      final isDone = newSection == 'Done';
      tasks[index] = task.copyWith(
        sectionId: newSection,
        isCompleted: isDone,
        completedAt: isDone ? DateTime.now().toUtc() : null,
        updatedAt: DateTime.now().toUtc(),
      );
      if (isDone && !task.isCompleted) karmaScore += 25;
      logActivity(EventType.taskUpdated, 'moved "${task.title}" to $newSection');
      notifyListeners();
    }
  }

  void createProject({
    required String name,
    required String colorHex,
    required String icon,
  }) {
    final now = DateTime.now();
    final newProject = Project(
      id: 'prj_${now.millisecondsSinceEpoch}',
      workspaceId: currentWorkspaceId,
      name: name.trim(),
      colorHex: colorHex,
      icon: icon,
      position: projects.length,
      createdAt: now,
      updatedAt: now,
    );

    projects.add(newProject);
    logActivity(EventType.taskCreated, 'created project: ${newProject.name}');
    notifyListeners();
  }

  void addKanbanColumn(String name) {
    if (name.trim().isNotEmpty && !kanbanColumns.contains(name.trim())) {
      kanbanColumns.add(name.trim());
      logActivity(EventType.taskUpdated, 'added Kanban column: ${name.trim()}');
      notifyListeners();
    }
  }

  void logActivity(EventType type, String message) {
    activities.insert(
      0,
      ActivityEvent(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        taskId: 'global',
        workspaceId: currentWorkspaceId,
        actorId: 'usr_demo_123',
        type: type,
        body: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Computed Query Helpers
  // ---------------------------------------------------------------------------

  int get completedTodayCount {
    final now = DateTime.now();
    return tasks.where((t) => t.isCompleted && t.dueAt != null && t.dueAt!.year == now.year && t.dueAt!.month == now.month && t.dueAt!.day == now.day).length;
  }

  int get pendingTodayCount {
    final now = DateTime.now();
    return tasks.where((t) => !t.isCompleted && t.dueAt != null && t.dueAt!.year == now.year && t.dueAt!.month == now.month && t.dueAt!.day == now.day).length;
  }

  int get overdueCount {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return tasks.where((t) => !t.isCompleted && t.dueAt != null && t.dueAt!.isBefore(todayStart)).length;
  }

  int get upcomingCount {
    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return tasks.where((t) => !t.isCompleted && t.dueAt != null && (t.dueAt!.isAfter(tomorrowStart) || t.dueAt!.isAtSameMomentAs(tomorrowStart))).length;
  }

  int get inboxCount {
    return tasks.where((t) => !t.isCompleted && t.projectId == 'prj_1').length;
  }

  double get todayProgress {
    final totalDue = pendingTodayCount + completedTodayCount;
    if (totalDue == 0) return 1.0;
    return (completedTodayCount / totalDue).clamp(0.0, 1.0);
  }

  Project getProject(String projectId) {
    return projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => projects.first,
    );
  }

  Workspace get currentWorkspace {
    return workspaces.firstWhere(
      (w) => w.id == currentWorkspaceId,
      orElse: () => workspaces.first,
    );
  }
}
