import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';
import 'serializers.dart';

class AuthViews {
  static Future<BloomResponse> signup(BloomRequest req) async {
    final body = await req.json();
    final dto = SignupDto.fromJson(body);

    // Mock user creation for template scaffold
    final user = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: dto.email,
      name: dto.name,
      createdAt: DateTime.now().toUtc(),
    );

    final token = TokenResponseDto(
      accessToken: 'jwt_${user.id}_mock_token',
      refreshToken: 'rf_${user.id}_mock_token',
      expiresIn: 86400,
      user: user,
    );

    return BloomResponse.json(token.toJson(), statusCode: 201);
  }

  static Future<BloomResponse> login(BloomRequest req) async {
    final body = await req.json();
    final dto = LoginDto.fromJson(body);

    final user = User(
      id: 'usr_demo_123',
      email: dto.email,
      name: 'Demo User',
      karmaScore: 1250,
      createdAt: DateTime.now().subtract(const Duration(days: 30)).toUtc(),
    );

    final token = TokenResponseDto(
      accessToken: 'jwt_${user.id}_mock_token',
      refreshToken: 'rf_${user.id}_mock_token',
      expiresIn: 86400,
      user: user,
    );

    return BloomResponse.json(token.toJson());
  }

  static Future<BloomResponse> refresh(BloomRequest req) async {
    return BloomResponse.json({
      'accessToken': 'jwt_refreshed_${DateTime.now().millisecondsSinceEpoch}',
      'expiresIn': 86400,
    });
  }

  static Future<BloomResponse> logout(BloomRequest req) async {
    return BloomResponse.json({'status': 'logged_out'});
  }

  static Future<BloomResponse> me(BloomRequest req) async {
    final user = User(
      id: req.headers['x-user-id'] ?? 'usr_demo_123',
      email: 'user@bloomtodo.dev',
      name: 'Demo User',
      karmaScore: 1250,
      createdAt: DateTime.now().subtract(const Duration(days: 30)).toUtc(),
    );

    return BloomResponse.json(user.toJson());
  }
}
