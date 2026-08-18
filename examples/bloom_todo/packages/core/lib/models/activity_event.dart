import 'package:equatable/equatable.dart';

enum EventType {
  taskCreated,
  taskCompleted,
  taskUpdated,
  commentAdded,
  assigneeChanged,
  dueDateChanged,
  priorityChanged;
}

class ActivityEvent extends Equatable {
  final String id;
  final String taskId;
  final String workspaceId;
  final String actorId;
  final EventType type;
  final String? body; // Markdown body for comments
  final Map<String, dynamic>? metadata; // Diff payload
  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.taskId,
    required this.workspaceId,
    required this.actorId,
    required this.type,
    this.body,
    this.metadata,
    required this.createdAt,
  });

  bool get isComment => type == EventType.commentAdded;

  ActivityEvent copyWith({
    String? id,
    String? taskId,
    String? workspaceId,
    String? actorId,
    EventType? type,
    String? body,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return ActivityEvent(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workspaceId: workspaceId ?? this.workspaceId,
      actorId: actorId ?? this.actorId,
      type: type ?? this.type,
      body: body ?? this.body,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'workspaceId': workspaceId,
      'actorId': actorId,
      'type': type.name,
      'body': body,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      workspaceId: json['workspaceId'] as String,
      actorId: json['actorId'] as String,
      type: EventType.values.byName(json['type'] as String),
      body: json['body'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    taskId,
    workspaceId,
    actorId,
    type,
    body,
    metadata,
    createdAt,
  ];
}
