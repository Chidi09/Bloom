// lib/models/project.dart

import 'package:equatable/equatable.dart';

// ---------------------------------------------------------------------------
// ViewStyle enum
// ---------------------------------------------------------------------------

/// The default layout used to display tasks in a project.
enum ViewStyle {
  list,
  board,
  calendar;

  static ViewStyle fromString(String value) => ViewStyle.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ViewStyle.list,
      );
}

// ---------------------------------------------------------------------------
// Project model
// ---------------------------------------------------------------------------

class Project extends Equatable {
  const Project({
    required this.id,
    required this.workspaceId,
    this.parentId,
    required this.name,
    this.colorHex = '#6B7280',
    this.icon = '📋',
    this.isFavorite = false,
    this.isShared = false,
    this.isArchived = false,
    this.defaultView = ViewStyle.list,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---- identity ----------------------------------------------------------

  final String id;

  /// Workspace that owns this project.
  final String workspaceId;

  /// Parent project ID for nested projects (self-referential).
  final String? parentId;

  // ---- display ------------------------------------------------------------

  final String name;

  /// Hex colour string including the `#` prefix, e.g. `#FF5733`.
  final String colorHex;

  /// Single emoji used as the project icon, e.g. `🚀`.
  final String icon;

  // ---- flags --------------------------------------------------------------

  final bool isFavorite;
  final bool isShared;
  final bool isArchived;

  // ---- layout & ordering --------------------------------------------------

  final ViewStyle defaultView;

  /// Position index within the sidebar list.
  final int position;

  // ---- timestamps ---------------------------------------------------------

  final DateTime createdAt;
  final DateTime updatedAt;

  // ---- copyWith -----------------------------------------------------------

  Project copyWith({
    String? id,
    String? workspaceId,
    Object? parentId = _sentinel,
    String? name,
    String? colorHex,
    String? icon,
    bool? isFavorite,
    bool? isShared,
    bool? isArchived,
    ViewStyle? defaultView,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      icon: icon ?? this.icon,
      isFavorite: isFavorite ?? this.isFavorite,
      isShared: isShared ?? this.isShared,
      isArchived: isArchived ?? this.isArchived,
      defaultView: defaultView ?? this.defaultView,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---- serialisation ------------------------------------------------------

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      colorHex: (json['color_hex'] as String?) ?? '#6B7280',
      icon: (json['icon'] as String?) ?? '📋',
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      isShared: (json['is_shared'] as bool?) ?? false,
      isArchived: (json['is_archived'] as bool?) ?? false,
      defaultView:
          ViewStyle.fromString(json['default_view'] as String? ?? 'list'),
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      if (parentId != null) 'parent_id': parentId,
      'name': name,
      'color_hex': colorHex,
      'icon': icon,
      'is_favorite': isFavorite,
      'is_shared': isShared,
      'is_archived': isArchived,
      'default_view': defaultView.name,
      'position': position,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // ---- equatable ----------------------------------------------------------

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        parentId,
        name,
        colorHex,
        icon,
        isFavorite,
        isShared,
        isArchived,
        defaultView,
        position,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() =>
      'Project(id: $id, name: "$name", view: ${defaultView.name})';
}

const Object _sentinel = Object();
