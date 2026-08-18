import 'package:equatable/equatable.dart';

enum WorkspacePlan {
  free,
  pro,
  business;

  String get displayName => switch (this) {
    free => 'Free',
    pro => 'Pro',
    business => 'Business',
  };

  int get maxMembers => switch (this) {
    free => 5,
    pro => 25,
    business => 500,
  };

  int get maxProjects => switch (this) {
    free => 5,
    pro => 300,
    business => 99999,
  };
}

class Workspace extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String ownerId;
  final WorkspacePlan plan;
  final int memberCount;
  final int taskCount;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    this.plan = WorkspacePlan.free,
    this.memberCount = 1,
    this.taskCount = 0,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Workspace copyWith({
    String? id,
    String? name,
    String? slug,
    String? ownerId,
    WorkspacePlan? plan,
    int? memberCount,
    int? taskCount,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      ownerId: ownerId ?? this.ownerId,
      plan: plan ?? this.plan,
      memberCount: memberCount ?? this.memberCount,
      taskCount: taskCount ?? this.taskCount,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'ownerId': ownerId,
      'plan': plan.name,
      'memberCount': memberCount,
      'taskCount': taskCount,
      'logoUrl': logoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      ownerId: json['ownerId'] as String,
      plan: WorkspacePlan.values.byName(json['plan'] as String? ?? 'free'),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      taskCount: (json['taskCount'] as num?)?.toInt() ?? 0,
      logoUrl: json['logoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    ownerId,
    plan,
    memberCount,
    taskCount,
    logoUrl,
    createdAt,
    updatedAt,
  ];
}
