# 37. Official Supabase Full-Stack Adapter

Bloom provides official first-class adapters for **Supabase**, bridging authentication, user sessions, token refresh, and CRUD table operations into Bloom's reactive architecture (`supabase_flutter: ^2.17.1`).

---

## ⚡ 1. Configuring Supabase Authentication

`BloomSupabaseAuthAdapter` extends `BloomAuth<BloomSupabaseUser>`, integrating session lifecycle and real-time auth state synchronization:

```dart
// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppBootstrapper implements BloomBootstrapper {
  @override
  Future<void> onBoot(BloomContainer container) async {
    // 1. Initialize Supabase Flutter Client
    await Supabase.initialize(
      url: BloomEnv.get('SUPABASE_URL'),
      anonKey: BloomEnv.get('SUPABASE_ANON_KEY'),
    );

    // 2. Register Bloom Supabase Auth Adapter
    final authAdapter = BloomSupabaseAuthAdapter(
      supabaseUrl: BloomEnv.get('SUPABASE_URL'),
      supabaseAnonKey: BloomEnv.get('SUPABASE_ANON_KEY'),
      supabaseClient: Supabase.instance.client,
      storage: BloomSecureStorage(),
      autoProvide: true, // Automatically registers as BloomAuthBase in DI
    );

    container.provideValue<BloomSupabaseAuthAdapter>(authAdapter);
  }
}
```

---

## 🔑 Authentication Workflows

### Sign In
```dart
final auth = inject<BloomSupabaseAuthAdapter>();

final user = await auth.signInWithPassword(
  email: 'alice@example.com',
  password: 'SecurePassword123!',
);

print('Logged in: ${user.id} (${auth.token.value})');
```

### Sign Up
```dart
final user = await auth.signUp(
  email: 'newuser@example.com',
  password: 'SecurePassword123!',
  data: {'full_name': 'Grace Hopper'},
);
```

### Refresh Session
Refreshes the active access token and updates all reactive subscribers automatically:
```dart
final updatedUser = await auth.refreshSession();
```

### Sign Out
```dart
await auth.logout();
```

---

## 📑 CRUD Table Repository (`BloomSupabaseTableRepository`)

Connect any Supabase database table to `BloomCrudRepository<T, String>`:

```dart
class Task {
  final String id;
  final String title;
  final bool isCompleted;

  const Task({required this.id, required this.title, this.isCompleted = false});

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    isCompleted: json['is_completed'] == true,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'is_completed': isCompleted,
  };
}

// Instantiate Repository
final taskRepository = BloomSupabaseTableRepository<Task>(
  tableName: 'tasks',
  supabaseUrl: BloomEnv.get('SUPABASE_URL'),
  supabaseAnonKey: BloomEnv.get('SUPABASE_ANON_KEY'),
  authTokenProvider: () => inject<BloomSupabaseAuthAdapter>().token.value,
  fromJson: Task.fromJson,
  toJson: (task) => task.toJson(),
);

// Perform CRUD
final allTasks = await taskRepository.findAll();
final newTask = await taskRepository.create(Task(id: '', title: 'Deploy v1.0'));
await taskRepository.update(newTask.id, Task(id: newTask.id, title: 'Deploy v1.0', isCompleted: true));
await taskRepository.delete(newTask.id);
```
