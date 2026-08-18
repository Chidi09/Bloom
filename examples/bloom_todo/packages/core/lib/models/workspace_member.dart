import 'package:equatable/equatable.dart';

enum MemberRole {
  owner,
  admin,
  editor,
  viewer;

  bool get canManageMembers => this == owner || this == admin;
  bool get canManageProjects => this == owner || this == admin || this == editor;
  bool get canEditTasks => this != viewer;
}

class WorkspaceMember extends Equatable {
  final String id;
  final String workspaceId;
  final String userId;
  final MemberRole role;
  final DateTime invitedAt;
  final DateTime? joinedAt;

  const WorkspaceMember({
    required this.id,
    required this.workspaceId,
    required this.userId,
    this.role = MemberRole.editor,
    required this.invitedAt,
    this.joinedAt,
  });

  bool get isPending => joinedAt == null;

  WorkspaceMember copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    MemberRole? role,
    DateTime? invitedAt,
    DateTime? joinedAt,
  }) {
    return WorkspaceMember(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      invitedAt: invitedAt ?? this.invitedAt,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'userId': userId,
      'role': role.name,
      'invitedAt': invitedAt.toIso8601String(),
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      userId: json['userId'] as String,
      role: MemberRole.values.byName(json['role'] as String? ?? 'editor'),
      invitedAt: DateTime.parse(json['invitedAt'] as String),
      joinedAt: json['joinedAt'] != null ? DateTime.parse(json['joinedAt'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, userId, role, invitedAt, joinedAt];
}
