# 25. Authentication & Session Management (`BloomAuth`)

`BloomAuth<U>` is a reactive user session manager that coordinates authentication state, hardware-backed secure token persistence, route guards, and automatic logout workflows.

---

## 🏗️ The `BloomAuthBase` Interface

Non-generic interface allowing route guards and HTTP interceptors to inspect authentication status without coupling to a concrete User class:

```dart
abstract class BloomAuthBase {
  ReadonlySignal<bool> get isAuthenticated;
  ReadonlySignal<String?> get token;
  Future<void> logout();
}
```

---

## ⚡ Initializing `BloomAuth<U>`

```dart
import 'package:bloom_framework/bloom.dart';

class User {
  final String id;
  final String email;
  final String role;

  const User({required this.id, required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    email: json['email'],
    role: json['role'] ?? 'user',
  );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'role': role};
}

// Instantiate BloomAuth
final auth = BloomAuth<User>(
  storage: BloomSecureStorage(),
  sessionKey: 'app_user_session',
  fromJson: User.fromJson,
  toJson: (u) => u.toJson(),
  autoProvide: true, // Registers as BloomAuthBase in DI container
);
```

---

## 🔄 Session Lifecycle

### 1. Setting an Authenticated Session
```dart
await auth.setSession(
  user: User(id: '123', email: 'alice@example.com', role: 'admin'),
  token: 'jwt_access_token_xyz',
);

print(auth.isAuthenticated.value); // true
print(auth.currentUser.value?.email); // 'alice@example.com'
```

### 2. Restoring Session on App Boot
On application launch inside `AppBootstrapper.onBoot()`, call `restoreSession()`:
```dart
final hasActiveSession = await auth.restoreSession();
if (hasActiveSession) {
  logger.info('Restored session for ${auth.currentUser.value?.email}');
}
```

### 3. Logging Out
Clears in-memory signals and deletes encrypted tokens from secure storage:
```dart
await auth.logout();
print(auth.isAuthenticated.value); // false
print(auth.currentUser.value);       // null
```

---

## 🛡️ Protecting Routes with `BloomAuthGuard`

Attach `BloomAuthGuard` to any route to redirect unauthenticated users automatically:

```dart
class DashboardRoute extends StatelessWidget {
  const DashboardRoute({super.key});

  static List<BloomGuard> get guards => [
    const BloomAuthGuard(loginPath: '/login'),
  ];

  @override
  Widget build(BuildContext context) => const Scaffold(...);
}
```
* If `auth.isAuthenticated` is `false`, navigation redirects to `/login?from=%2Fdashboard`.
