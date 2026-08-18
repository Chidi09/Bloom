import 'package:equatable/equatable.dart';

sealed class DeltaEvent extends Equatable {
  final String type;
  final String workspaceId;
  final String entityId;
  final String actorId;
  final DateTime timestamp;

  const DeltaEvent({
    required this.type,
    required this.workspaceId,
    required this.entityId,
    required this.actorId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();
}

class TaskDeltaEvent extends DeltaEvent {
  final String action; // created | updated | completed | deleted | moved
  final Map<String, dynamic>? diff;

  const TaskDeltaEvent({
    required super.workspaceId,
    required super.entityId,
    required super.actorId,
    required super.timestamp,
    required this.action,
    this.diff,
  }) : super(type: 'task:$action');

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'action': action,
    'workspaceId': workspaceId,
    'taskId': entityId,
    'actorId': actorId,
    'diff': diff,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TaskDeltaEvent.fromJson(Map<String, dynamic> json) {
    return TaskDeltaEvent(
      workspaceId: json['workspaceId'] as String,
      entityId: (json['taskId'] ?? json['entityId']) as String,
      actorId: json['actorId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String? ?? 'updated',
      diff: json['diff'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
    type,
    action,
    workspaceId,
    entityId,
    actorId,
    diff,
    timestamp,
  ];
}

class ProjectDeltaEvent extends DeltaEvent {
  final String action;
  final Map<String, dynamic>? diff;

  const ProjectDeltaEvent({
    required super.workspaceId,
    required super.entityId,
    required super.actorId,
    required super.timestamp,
    required this.action,
    this.diff,
  }) : super(type: 'project:$action');

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'action': action,
    'workspaceId': workspaceId,
    'projectId': entityId,
    'actorId': actorId,
    'diff': diff,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ProjectDeltaEvent.fromJson(Map<String, dynamic> json) {
    return ProjectDeltaEvent(
      workspaceId: json['workspaceId'] as String,
      entityId: (json['projectId'] ?? json['entityId']) as String,
      actorId: json['actorId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String? ?? 'updated',
      diff: json['diff'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
    type,
    action,
    workspaceId,
    entityId,
    actorId,
    diff,
    timestamp,
  ];
}

class CommentDeltaEvent extends DeltaEvent {
  final String taskId;
  final String body;

  const CommentDeltaEvent({
    required super.workspaceId,
    required super.entityId,
    required super.actorId,
    required super.timestamp,
    required this.taskId,
    required this.body,
  }) : super(type: 'comment:added');

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'workspaceId': workspaceId,
    'commentId': entityId,
    'taskId': taskId,
    'actorId': actorId,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CommentDeltaEvent.fromJson(Map<String, dynamic> json) {
    return CommentDeltaEvent(
      workspaceId: json['workspaceId'] as String,
      entityId: (json['commentId'] ?? json['entityId']) as String,
      taskId: json['taskId'] as String,
      actorId: json['actorId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      body: json['body'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    type,
    workspaceId,
    entityId,
    taskId,
    actorId,
    body,
    timestamp,
  ];
}
