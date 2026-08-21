# `bloom generate` CLI Reference Manual

Generates type-safe boilerplate components (routes, state controllers, domain models, services, repositories) and keeps filesystem routing tables (`routes.g.dart`) synchronized.

---

## 1. Synopsis

```bash
bloom generate <subcommand> [name] [options]
```

### Supported Subcommands
* `bloom generate route <path>`: Generates a new file-based route widget and updates `routes.g.dart`.
* `bloom generate controller <name>`: Generates a `BloomController` with reactive signals and lifecycle hooks.
* `bloom generate model <name>`: Generates an immutable, typed domain model with `fromJson` and `toJson`.
* `bloom generate service <name>`: Generates an injectable service registered in `BloomContainer`.
* `bloom generate router`: Rescans `lib/routes/` and re-generates `lib/app/routes.g.dart`.

---

## 2. Examples

### Generating a Dynamic Route
```bash
bloom generate route "tasks/[id]"
```
Generates `lib/routes/tasks/[id].dart`:
```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:flutter/material.dart';

class TaskDetailRoute extends StatelessWidget {
  final String id;
  const TaskDetailRoute({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task $id')),
      body: Center(child: Text('Details for task $id')),
    );
  }
}
```

### Generating a Reactive Controller
```bash
bloom generate controller Task
```
Generates `lib/controllers/task_controller.dart`:
```dart
import 'package:bloom_framework/bloom_framework.dart';

class TaskController extends BloomController {
  final tasks = signal<List<Task>>([]);
  final isLoading = signal(false);

  @override
  void onInit() {
    super.onInit();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    isLoading.value = true;
    try {
      // Fetch logic
    } finally {
      isLoading.value = false;
    }
  }
}
```
