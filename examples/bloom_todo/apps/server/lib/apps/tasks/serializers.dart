import 'package:bloom_todo_core/core.dart';

class TaskCreateDto {
  final String title;
  final String? description;
  final String projectId;
  final String? sectionId;
  final String workspaceId;
  final Priority priority;
  final DateTime? dueAt;
  final String? recurrenceRule;
  final List<String> labels;

  const TaskCreateDto({
    required this.title,
    this.description,
    required this.projectId,
    this.sectionId,
    required this.workspaceId,
    this.priority = Priority.p4,
    this.dueAt,
    this.recurrenceRule,
    this.labels = const [],
  });

  factory TaskCreateDto.fromJson(Map<String, dynamic> json) => TaskCreateDto(
    title: json['title'] as String,
    description: json['description'] as String?,
    projectId: json['projectId'] as String,
    sectionId: json['sectionId'] as String?,
    workspaceId: json['workspaceId'] as String,
    priority: Priority.values.byName(json['priority'] as String? ?? 'p4'),
    dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt'] as String) : null,
    recurrenceRule: json['recurrenceRule'] as String?,
    labels: (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  );
}

class TaskUpdateDto {
  final String? title;
  final String? description;
  final String? projectId;
  final String? sectionId;
  final Priority? priority;
  final DateTime? dueAt;
  final String? recurrenceRule;
  final bool? isCompleted;
  final int? position;
  final List<String>? labels;

  const TaskUpdateDto({
    this.title,
    this.description,
    this.projectId,
    this.sectionId,
    this.priority,
    this.dueAt,
    this.recurrenceRule,
    this.isCompleted,
    this.position,
    this.labels,
  });

  factory TaskUpdateDto.fromJson(Map<String, dynamic> json) => TaskUpdateDto(
    title: json['title'] as String?,
    description: json['description'] as String?,
    projectId: json['projectId'] as String?,
    sectionId: json['sectionId'] as String?,
    priority: json['priority'] != null ? Priority.values.byName(json['priority'] as String) : null,
    dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt'] as String) : null,
    recurrenceRule: json['recurrenceRule'] as String?,
    isCompleted: json['isCompleted'] as bool?,
    position: json['position'] as int?,
    labels: (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList(),
  );
}
