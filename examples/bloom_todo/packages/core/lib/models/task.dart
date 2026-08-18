// lib/models/task.dart
//
// Task is the central entity of bloom_todo.  Every field maps 1-to-1 to a
// column in the `tasks` table managed by bloom_db.

import 'package:equatable/equatable.dart';

// ---------------------------------------------------------------------------
// Priority enum
// ---------------------------------------------------------------------------

/// Todoist-style priority where [p1] is the most urgent.
enum Priority {
  p1,
  p2,
  p3,
  p4;

  /// Human-readable label shown in the UI.
  String get label {
    switch (this) {
      case Priority.p1:
        return 'Priority 1';
      case Priority.p2:
        return 'Priority 2';
      case Priority.p3:
        return 'Priority 3';
      case Priority.p4:
        return 'No Priority';
    }
  }

  /// Colour hint (hex) used by the UI layer.
  String get colorHex {
    switch (this) {
      case Priority.p1:
        return '#FF4444';
      case Priority.p2:
        return '#FF9800';
      case Priority.p3:
        return '#2196F3';
      case Priority.p4:
        return '#9E9E9E';
    }
  }

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Priority.p4,
    );
  }
}

// ---------------------------------------------------------------------------
// Task model
// ---------------------------------------------------------------------------

class Task extends Equatable {
  const Task({
    required this.id,
    this.parentId,
    required this.projectId,
    this.sectionId,
    required this.workspaceId,
    required this.creatorId,
    this.assigneeId,
    required this.title,
    this.description,
    this.priority = Priority.p4,
    this.dueAt,
    this.recurrenceRule,
    this.position = 0,
    this.isCompleted = false,
    this.completedAt,
    this.labels = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // ---- identity ----------------------------------------------------------

  /// UUID v4 primary key.
  final String id;

  /// Parent task ID for sub-task nesting (self-referential FK).
  final String? parentId;

  // ---- foreign keys -------------------------------------------------------

  /// Project this task belongs to.
  final String projectId;

  /// Optional section within the project (kanban column, etc.).
  final String? sectionId;

  /// Workspace the task lives in.
  final String workspaceId;

  /// User who created the task.
  final String creatorId;

  /// User currently assigned to this task (nullable).
  final String? assigneeId;

  // ---- content ------------------------------------------------------------

  final String title;

  /// Optional markdown description.
  final String? description;

  final Priority priority;

  /// Due date/time in UTC.  Null means no due date.
  final DateTime? dueAt;

  /// RFC 5545 RRULE string, e.g. `FREQ=WEEKLY;BYDAY=MO,WE`.
  final String? recurrenceRule;

  // ---- ordering & status --------------------------------------------------

  /// Fractional index position within its container (project/section).
  final int position;

  final bool isCompleted;

  final DateTime? completedAt;

  // ---- labels -------------------------------------------------------------

  /// Ordered list of label IDs attached to this task.
  final List<String> labels;

  // ---- timestamps ---------------------------------------------------------

  final DateTime createdAt;
  final DateTime updatedAt;

  // ---- copyWith -----------------------------------------------------------

  Task copyWith({
    String? id,
    Object? parentId = _sentinel,
    String? projectId,
    Object? sectionId = _sentinel,
    String? workspaceId,
    String? creatorId,
    Object? assigneeId = _sentinel,
    String? title,
    Object? description = _sentinel,
    Priority? priority,
    Object? dueAt = _sentinel,
    Object? recurrenceRule = _sentinel,
    int? position,
    bool? isCompleted,
    Object? completedAt = _sentinel,
    List<String>? labels,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      projectId: projectId ?? this.projectId,
      sectionId: sectionId == _sentinel ? this.sectionId : sectionId as String?,
      workspaceId: workspaceId ?? this.workspaceId,
      creatorId: creatorId ?? this.creatorId,
      assigneeId:
          assigneeId == _sentinel ? this.assigneeId : assigneeId as String?,
      title: title ?? this.title,
      description:
          description == _sentinel ? this.description : description as String?,
      priority: priority ?? this.priority,
      dueAt: dueAt == _sentinel ? this.dueAt : dueAt as DateTime?,
      recurrenceRule: recurrenceRule == _sentinel
          ? this.recurrenceRule
          : recurrenceRule as String?,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt:
          completedAt == _sentinel ? this.completedAt : completedAt as DateTime?,
      labels: labels ?? this.labels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---- serialisation ------------------------------------------------------

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      projectId: json['project_id'] as String,
      sectionId: json['section_id'] as String?,
      workspaceId: json['workspace_id'] as String,
      creatorId: json['creator_id'] as String,
      assigneeId: json['assignee_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: Priority.fromString(json['priority'] as String? ?? 'p4'),
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String),
      recurrenceRule: json['recurrence_rule'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (parentId != null) 'parent_id': parentId,
      'project_id': projectId,
      if (sectionId != null) 'section_id': sectionId,
      'workspace_id': workspaceId,
      'creator_id': creatorId,
      if (assigneeId != null) 'assignee_id': assigneeId,
      'title': title,
      if (description != null) 'description': description,
      'priority': priority.name,
      if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      'position': position,
      'is_completed': isCompleted,
      if (completedAt != null)
        'completed_at': completedAt!.toUtc().toIso8601String(),
      'labels': labels,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // ---- equatable ----------------------------------------------------------

  @override
  List<Object?> get props => [
        id,
        parentId,
        projectId,
        sectionId,
        workspaceId,
        creatorId,
        assigneeId,
        title,
        description,
        priority,
        dueAt,
        recurrenceRule,
        position,
        isCompleted,
        completedAt,
        labels,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() =>
      'Task(id: $id, title: "$title", priority: ${priority.name}, '
      'isCompleted: $isCompleted)';
}

// Internal sentinel so copyWith can distinguish `null` from "not provided".
const Object _sentinel = Object();
