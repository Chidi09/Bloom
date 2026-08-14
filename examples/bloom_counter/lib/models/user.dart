// lib/models/${className.toLowerCase()}.dart

class User {
  final String id;
  final String title;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
