import 'package:equatable/equatable.dart';

enum AppTheme {
  light,
  dark,
  system;
}

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String timezone;
  final int weekStart; // 0 = Monday, 6 = Sunday
  final AppTheme theme;
  final int karmaScore;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.timezone = 'UTC',
    this.weekStart = 0,
    this.theme = AppTheme.system,
    this.karmaScore = 0,
    required this.createdAt,
  });

  String get karmaLevel {
    if (karmaScore < 500) return 'Novice';
    if (karmaScore < 2500) return 'Intermediate';
    if (karmaScore < 7500) return 'Advanced';
    if (karmaScore < 15000) return 'Professional';
    if (karmaScore < 30000) return 'Expert';
    return 'Grandmaster';
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? timezone,
    int? weekStart,
    AppTheme? theme,
    int? karmaScore,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timezone: timezone ?? this.timezone,
      weekStart: weekStart ?? this.weekStart,
      theme: theme ?? this.theme,
      karmaScore: karmaScore ?? this.karmaScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'timezone': timezone,
      'weekStart': weekStart,
      'theme': theme.name,
      'karmaScore': karmaScore,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      weekStart: (json['weekStart'] as num?)?.toInt() ?? 0,
      theme: AppTheme.values.byName(json['theme'] as String? ?? 'system'),
      karmaScore: (json['karmaScore'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    avatarUrl,
    timezone,
    weekStart,
    theme,
    karmaScore,
    createdAt,
  ];
}
