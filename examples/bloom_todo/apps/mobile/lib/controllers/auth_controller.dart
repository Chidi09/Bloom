import 'package:signals/signals.dart';
import 'package:bloom_todo_core/core.dart';
import '../app/api_client.dart';
import '../app/guards.dart';

class AuthController {
  final ApiClient api;

  final currentUser = signal<User?>(null);
  late final isAuthenticated = computed(() => currentUser.value != null);

  AuthController(this.api);

  Future<void> login(String email, String password) async {
    final res = await api.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    api.setToken(res['accessToken'] as String);
    currentUser.value = user;
    AuthGuard.isAuthenticated = true;
  }

  Future<void> signup(String email, String password, String name) async {
    final res = await api.post(
      ApiEndpoints.signup,
      body: {'email': email, 'password': password, 'name': name},
    );
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    api.setToken(res['accessToken'] as String);
    currentUser.value = user;
    AuthGuard.isAuthenticated = true;
  }

  void logout() {
    api.setToken(null);
    currentUser.value = null;
    AuthGuard.isAuthenticated = false;
  }
}
