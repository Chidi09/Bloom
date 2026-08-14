# 05. Filesystem Routing & Navigation

## 1. Routing Strategy

Bloom leverages `go_router` as its underlying, battle-tested execution engine while providing an intuitive **Next.js-style filesystem routing convention** and deterministic code generator.

```text
lib/routes/ Directory
         ↓
Bloom Route Scanner (AST analyzer)
         ↓
Route Metadata Table
         ↓
Generated GoRouter Configuration (`lib/app/generated_router.dart`)
         ↓
Flutter Application Navigation
```

---

## 2. Filesystem Routing Conventions

Files placed under `lib/routes/` are automatically mapped to URI path patterns:

| File Path | URL Pattern | Description |
| :--- | :--- | :--- |
| `lib/routes/index.dart` | `/` | Root / Landing page |
| `lib/routes/login.dart` | `/login` | Static route |
| `lib/routes/settings.dart` | `/settings` | Static route |
| `lib/routes/users/index.dart` | `/users` | Collection index |
| `lib/routes/users/[id].dart` | `/users/:id` | Dynamic parameter route |
| `lib/routes/users/[id]/edit.dart` | `/users/:id/edit` | Nested parameterized route |
| `lib/routes/(auth)/login.dart` | `/login` | Route grouping (omits folder from path) |

---

## 3. Route Component Declaration

```dart
// lib/routes/users/[id].dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class UserDetailRoute extends BloomRoute {
  final String id;
  const UserDetailRoute({required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User $id')),
      body: Center(child: Text('Profile details for ID: $id')),
    );
  }
}
```

---

## 4. Route Guards & Middleware

Route protection is declared using declarative guards. Guards integrate directly with Bloom's DI container and state:

```dart
// lib/routes/dashboard.dart
import 'package:bloom_framework/bloom.dart';
import '../features/auth/guards/auth_guard.dart';

@BloomRouteConfig(
  guards: [AuthGuard],
)
class DashboardRoute extends BloomRoute {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Protected Dashboard')),
    );
  }
}
```

```dart
// lib/features/auth/guards/auth_guard.dart
import 'package:bloom_framework/bloom.dart';
import '../controllers/auth_controller.dart';

class AuthGuard extends BloomGuard {
  @override
  Future<GuardResult> canActivate(BuildContext context, RouteMatch match) async {
    final auth = inject<AuthController>();
    
    if (auth.isAuthenticated.value) {
      return GuardResult.allow();
    }
    
    // Redirect unauthenticated requests to login with redirect back param
    return GuardResult.redirect('/login?from=${match.location}');
  }
}
```

---

## 5. Nested Layouts & Tab Navigation

Bloom uses directory grouping syntax `(group_name)` to construct `ShellRoute` and persistent tab navigators:

```text
lib/routes/
├── (tabs)/
│   ├── _layout.dart        # Shell layout containing Scaffold with BottomNavigationBar
│   ├── home.dart           # Tab 1: /home
│   ├── search.dart         # Tab 2: /search
│   └── profile.dart        # Tab 3: /profile
└── login.dart              # Fullscreen route outside the tab shell
```

```dart
// lib/routes/(tabs)/_layout.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class TabsLayout extends BloomLayout {
  final Widget child;
  const TabsLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentPath = BloomRouter.currentLocation(context);
    
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(currentPath),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

---

## 6. Deep Linking Configuration

Configure custom URL schemes and universal domains directly in `bloom.yaml`:

```yaml
# bloom.yaml
deep_links:
  enabled: true
  schemes:
    - myapp
  domains:
    - app.bloom.dev
```

Bloom's build generator automatically updates:
* `AndroidManifest.xml` (Intent filters for App Links)
* `Info.plist` (Associated Domains / Universal Links)
* Web URL routing strategies (Path URL strategy)
