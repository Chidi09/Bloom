import 'package:equatable/equatable.dart';

class Label extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String colorHex;
  final int position;
  final DateTime createdAt;

  const Label({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.colorHex,
    this.position = 0,
    required this.createdAt,
  });

  Label copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? colorHex,
    int? position,
    DateTime? createdAt,
  }) {
    return Label(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'name': name,
      'colorHex': colorHex,
      'position': position,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, name, colorHex, position, createdAt];
}
