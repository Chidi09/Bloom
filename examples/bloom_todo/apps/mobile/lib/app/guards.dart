class AuthGuard {
  static bool isAuthenticated = false;

  static String? redirect(String location) {
    final isAuthRoute = location == '/login' || location == '/signup';

    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    if (isAuthenticated && isAuthRoute) {
      return '/today';
    }

    return null;
  }
}
