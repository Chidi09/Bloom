# 15. Declarative Filesystem Routing & Navigation

Bloom introduces Next.js-style file-based routing to Flutter. You declare screens by creating files inside `lib/routes/`, and the Bloom CLI automatically compiles them into a strongly-typed `GoRouter` table in `lib/app/routes.g.dart`.

---

## 🗂️ Filesystem Conventions

| File Path in `lib/routes/` | Generated Route URL | Component Class Name |
| :--- | :--- | :--- |
| `index.dart` | `/` | `IndexRoute` |
| `settings.dart` | `/settings` | `SettingsRoute` |
| `users/[id].dart` | `/users/:id` | `UsersIdRoute` |
| `posts/[category]/[slug].dart` | `/posts/:category/:slug` | `PostsCategorySlugRoute` |
| `(auth)/login.dart` | `/login` | `LoginRoute` |
| `(auth)/register.dart` | `/register` | `RegisterRoute` |
| `_layout.dart` | Shell Route (`/`) | `LayoutRoute` |

---

## 🔗 Route Groups: `(group_name)/`

Directories wrapped in parentheses (e.g. `(auth)` or `(dashboard)`) organize routes into logical modules without modifying the URL path.

```text
lib/routes/
├── (auth)/
│   ├── login.dart       ➔ URL: /login
│   └── register.dart    ➔ URL: /register
└── (marketing)/
    ├── about.dart       ➔ URL: /about
    └── pricing.dart     ➔ URL: /pricing
```

---

## 🖼️ Shell Layouts: `_layout.dart`

When `_layout.dart` exists in a directory, Bloom wraps all sibling and child routes in a persistent `ShellRoute`. Ideal for bottom navigation bars or responsive sidebars:

```dart
// lib/routes/_layout.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class LayoutRoute extends StatelessWidget {
  final Widget child;

  const LayoutRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) {
          if (index == 0) BloomRouter.go('/');
          if (index == 1) BloomRouter.go('/explore');
          if (index == 2) BloomRouter.go('/profile');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }
}
```

---

## 🛡️ Route Guards & Authentication (`BloomAuthGuard`)

Route guards intercept navigation before a page mounts:

```dart
// lib/routes/profile.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class ProfileRoute extends StatelessWidget {
  const ProfileRoute({super.key});

  // Attach route guard
  static List<BloomGuard> get guards => [
    const BloomAuthGuard(loginPath: '/login'),
  ];

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Protected Profile')));
  }
}
```

### Creating a Custom Guard
```dart
class AdminGuard implements BloomGuard {
  const AdminGuard();

  @override
  GuardResult canActivate(BuildContext context, BloomRouteMatch match) {
    final user = inject<BloomAuthBase>().currentUser;
    if (user.value != null && user.value!.role == 'admin') {
      return GuardResult.allow();
    }
    return GuardResult.redirect('/forbidden');
  }
}
```

---

## 🧭 Programmatic Navigation (`BloomRouter`)

Navigate anywhere using typed static helpers:

```dart
// Imperative navigation
BloomRouter.go('/users/42');

// Push onto navigation stack
BloomRouter.push('/settings');

// Replace active route
BloomRouter.replace('/dashboard');

// Pop active route
BloomRouter.pop();

// Access active route state
final match = BloomRouter.currentMatch;
print(match?.path);      // '/users/:id'
print(match?.location);  // '/users/42'
```
