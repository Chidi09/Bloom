import 'package:equatable/equatable.dart';

class Section extends Equatable {
  final String id;
  final String projectId;
  final String name;
  final int position;
  final bool isCollapsed;
  final DateTime createdAt;

  const Section({
    required this.id,
    required this.projectId,
    required this.name,
    this.position = 0,
    this.isCollapsed = false,
    required this.createdAt,
  });

  Section copyWith({
    String? id,
    String? projectId,
    String? name,
    int? position,
    bool? isCollapsed,
    DateTime? createdAt,
  }) {
    return Section(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      position: position ?? this.position,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'name': name,
      'position': position,
      'isCollapsed': isCollapsed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isCollapsed: (json['isCollapsed'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, projectId, name, position, isCollapsed, createdAt];
}
