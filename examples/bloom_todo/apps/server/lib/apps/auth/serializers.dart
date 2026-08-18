import 'package:bloom_todo_core/core.dart';

class LoginDto {
  final String email;
  final String password;

  const LoginDto({required this.email, required this.password});

  factory LoginDto.fromJson(Map<String, dynamic> json) => LoginDto(
    email: json['email'] as String,
    password: json['password'] as String,
  );
}

class SignupDto {
  final String email;
  final String password;
  final String name;

  const SignupDto({
    required this.email,
    required this.password,
    required this.name,
  });

  factory SignupDto.fromJson(Map<String, dynamic> json) => SignupDto(
    email: json['email'] as String,
    password: json['password'] as String,
    name: json['name'] as String,
  );
}

class TokenResponseDto {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final User user;

  const TokenResponseDto({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'user': user.toJson(),
  };
}
