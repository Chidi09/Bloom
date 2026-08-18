import 'package:equatable/equatable.dart';

enum NotificationType {
  mention,
  assignment,
  reminder,
  invite,
  update;
}

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? taskId;
  final String? projectId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.taskId,
    this.projectId,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? taskId,
    String? projectId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'taskId': taskId,
      'projectId': projectId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.byName(json['type'] as String),
      taskId: json['taskId'] as String?,
      projectId: json['projectId'] as String?,
      isRead: (json['isRead'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    body,
    type,
    taskId,
    projectId,
    isRead,
    createdAt,
  ];
}
