# Bloom for Flutter Developers: The Complete Architectural Guide

Welcome to the definitive guide for **Flutter engineers** building full-stack, enterprise-grade applications with **Bloom**.

Flutter revolutionized cross-platform mobile and desktop development with its single codebase, hot reload, and custom rendering engine. However, when targeting high-throughput web dashboards, public landing pages with strict SEO requirements, or building multi-isolate backend server infrastructure, traditional Flutter patterns encounter friction.

**Bloom bridges this gap.** It brings a unified full-stack architecture that allows you to write Flutter for mobile and desktop, **Bloom JS Native** for high-performance lightweight web, and **Bloom Server** for multi-isolate backend APIs—all sharing the exact same domain entities, validation logic, and reactive patterns.

---

## 1. Executive Summary: What Bloom Adds to Flutter

| Dimension | Standard Flutter Setup | Bloom Full-Stack Ecosystem |
| :--- | :--- | :--- |
| **Monorepo Scope** | Client app only (requires separate Node/Go/Python backend) | **Unified Full-Stack**: Mobile (`apps/mobile`), Web (`apps/web`), Server (`apps/server`), Shared Core (`packages/core`). |
| **Domain Models** | Duplicated across backend schema, client models, and API types | **Single Source of Truth**: Models defined once in `packages/core` and shared 1-to-1 across client and server. |
| **Web Rendering** | CanvasKit / SkWasm (~2.5MB download, inaccessible to crawlers) | **Bloom JS Native**: Pure Dart DOM AST (<250kB bundle, `<0.4ms` SSR, native browser text selection, full SEO). |
| **State Management** | Fragmented across Riverpod, BLoC, Provider, Redux | **Bloom Signals**: Fine-grained reactive signals (`signal()`, `computed()`, `effect()`) matching SolidJS/Angular signals. |
| **Design System** | Default Material 3 / Cupertino | **Bloom UI**: Dark, engineering-grade Linear/Vercel-inspired primitives (`BloomCard`, `BloomBadge`, `BloomKbd`). |
| **Developer Tooling** | `flutter run`, manual ADB commands | **`bloom dev`**: Interactive dashboard, QR pairing with Bloom Go, UDP discovery, automated manifest prebuilds. |
| **OTA Code Push** | Manual Shorebird CLI commands | **Native `bloom deploy`**: Orchestrated Shorebird OTA patching with release fingerprinting. |

---

## 2. Master Conceptual Rosetta Stone

| Flutter Concept | Bloom Full-Stack / JS Native Equivalent |
| :--- | :--- |
| `Widget` | `BloomNode` (Pure Dart AST descriptor: `Div`, `Span`, `Button`, `Section`) |
| `StatelessWidget` | Pure function or stateless class returning a `BloomNode` tree |
| `StatefulWidget` / `setState()` | `signal<T>()` + `Live(() => ...)` |
| `ChangeNotifier` / `ValueNotifier` | `Signal<T>` / `Computed<T>` |
| `Column(children: [...])` | `Div(className: 'flex flex-col gap-2', children: [...])` |
| `Row(children: [...])` | `Div(className: 'flex flex-row items-center gap-3', children: [...])` |
| `Container(decoration: BoxDecoration(...))` | `BloomCard` / `Div(className: 'p-4 rounded-xl bg-[#14141A] border border-[#1E1E24]')` |
| `ListView.builder()` | `ForEach<T>(() => list.value, (item) => ItemView(item), key: (item) => item.id)` |
| `Visibility(visible: condition)` | `Show(when: () => condition.value, builder: () => ..., fallback: () => ...)` |
| `Navigator.pushNamed()` / `GoRouter` | `BloomRouter` (Mobile) / Filesystem-based dynamic routing (`web/routes/`) |
| `ThemeData(brightness: Brightness.dark)` | Dark Carbon Design System (`#09090B`, `#14141A`, `#1E1E24`, `#6366F1`) |
| `flutter test` | `flutter test` (Widgets) + `dart test` (Stores, API, SSR, JS Native AST on VM in `<50ms`) |

---

## 3. Architecture: The Single Source of Truth (`packages/core`)

In traditional architectures, client and server code drift over time. In Bloom, all domain entities, validation schemas, and business constants live in `packages/core`.

### 3.1 Defining Domain Entities

```dart
// packages/core/lib/src/models/task.dart
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

enum Priority {
  p1(label: 'Urgent', colorHex: '#EF4444'),
  p2(label: 'High', colorHex: '#F59E0B'),
  p3(label: 'Normal', colorHex: '#3B82F6'),
  p4(label: 'Low', colorHex: '#71717A');

  final String label;
  final String colorHex;
  const Priority({required this.label, required this.colorHex});
}

@immutable
class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String projectId;
  final Priority priority;
  final bool isCompleted;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.projectId,
    this.priority = Priority.p3,
    this.isCompleted = false,
    required this.createdAt,
  });

  Task copyWith({
    String? title,
    String? description,
    String? projectId,
    Priority? priority,
    bool? isCompleted,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      projectId: json['projectId'] as String? ?? 'proj_inbox',
      priority: Priority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => Priority.p3,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'projectId': projectId,
    'priority': priority.name,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, title, description, projectId, priority, isCompleted, createdAt];
}
```

---

## 4. UI Architecture: Bloom UI vs. Material Widgets

Bloom enforces strict design system guidelines: **no toy emojis, deep carbon backgrounds (`#09090B`), subtle surfaces (`#14141A`), and crisp borders (`#1E1E24`)**.

### 4.1 Mobile / Flutter UI Implementation (`apps/mobile`)

```dart
// apps/mobile/lib/views/task_card.dart
import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';
import 'package:bloom_todo_core/core.dart';

class TaskCardWidget extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            BloomCheckbox(
              value: task.isCompleted,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? const Color(0xFF71717A) : Colors.white,
                    ),
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                    ),
                  ],
                ],
              ),
            ),
            BloomBadge(
              text: task.priority.label,
              variant: switch (task.priority) {
                Priority.p1 => BloomBadgeVariant.p1,
                Priority.p2 => BloomBadgeVariant.p2,
                Priority.p3 => BloomBadgeVariant.p3,
                Priority.p4 => BloomBadgeVariant.secondary,
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4.2 Web UI Implementation with Bloom JS Native (`apps/web`)

```dart
// apps/web/lib/views/task_row.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_todo_core/core.dart';
import '../ui/badge.dart';
import '../ui/components.dart';

class TaskRowComponent {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const TaskRowComponent({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  BloomNode build() {
    return Div(
      className: 'p-3 rounded-xl bg-[#14141A] border border-[#1E1E24] hover:border-[#27272A] flex items-center justify-between transition-all cursor-pointer select-none',
      onClick: (_) => onTap(),
      children: [
        Div(
          className: 'flex items-center gap-3 min-w-0 flex-1',
          children: [
            ShadcnCheckbox.render(
              checked: task.isCompleted,
              onToggle: () => onToggle(),
            ),
            Div(
              className: 'flex flex-col min-w-0 flex-1',
              children: [
                Span(
                  className: 'text-xs font-medium text-white truncate ${task.isCompleted ? "line-through text-zinc-500" : ""}',
                  text: task.title,
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Span(
                    className: 'text-[11px] text-zinc-500 truncate',
                    text: task.description!,
                  ),
              ],
            ),
          ],
        ),
        ShadcnBadge.render(
          text: task.priority.label,
          variant: switch (task.priority) {
            Priority.p1 => ShadcnBadgeVariant.destructive,
            Priority.p2 => ShadcnBadgeVariant.warning,
            Priority.p3 => ShadcnBadgeVariant.defaultVariant,
            Priority.p4 => ShadcnBadgeVariant.secondary,
          },
        ),
      ],
    );
  }
}
```

---

## 5. State Management: Signals vs. Riverpod / BLoC

Why did Bloom adopt Signals over Riverpod or BLoC?

1. **Zero Boilerplate**: No `StateNotifier`, `StateNotifierProvider`, `Event`, `State`, `mapEventToState` classes.
2. **Fine-Grained Execution**: Mutating a signal only notifies the exact listener subscribing to that property.
3. **Universal Compatibility**: Signals run identically on Flutter Mobile, Flutter Desktop, Bloom JS Native Web, and Server-Side Dart Isolates.

```dart
// apps/web/lib/state/todo_store.dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_todo_core/core.dart';
import '../api/todo_api_client.dart';

class TodoStore {
  static final TodoStore instance = TodoStore._();
  TodoStore._();

  final tasks = signal<List<Task>>([]);
  final activeNav = signal(0); // 0: Today, 1: Projects, 2: Upcoming, 3: Inbox
  final selectedTaskId = signal<String?>(null);

  // Derived Signal (Auto-memoized)
  late final todayTasks = computed(() =>
    tasks.value.where((t) => !t.isCompleted).toList()
  );

  late final selectedTask = computed(() =>
    tasks.value.where((t) => t.id == selectedTaskId.value).firstOrNull
  );

  // Actions
  void toggleTask(String taskId) {
    tasks.update((current) => current.map((t) {
      if (t.id == taskId) return t.copyWith(isCompleted: !t.isCompleted);
      return t;
    }).toList());
  }
}
```

---

## 6. Testing Philosophy: 0ms Overhead Dart VM Unit Tests

In standard Flutter, widget testing requires initializing the Flutter test binding (`testWidgets()`), which incurs rendering pipeline overhead.

With Bloom JS Native and Core Stores:
* **100% Pure Dart VM Execution**: Test your stores, domain entities, and API clients using standard `dart test`.
* **Execution Speed**: 200+ unit tests execute in `< 1.5 seconds`.

```dart
// test/state/todo_store_test.dart
import 'package:test/test.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_web/state/todo_store.dart';

void main() {
  group('TodoStore VM Unit Tests', () {
    late TodoStore store;

    setUp(() {
      store = TodoStore.instance;
      store.tasks.value = [
        Task(id: '1', title: 'Test Task', projectId: 'proj_inbox', createdAt: DateTime.now()),
      ];
    });

    test('toggles task completion reactively', () {
      expect(store.todayTasks.value.length, 1);
      store.toggleTask('1');
      expect(store.todayTasks.value.length, 0);
    });
  });
}
```

---

## 7. Developer CLI Command Reference

```bash
# Start interactive mobile/desktop dev session with hot reload & QR pairing
bloom dev

# Start high-performance web client with live reload
bloom js dev --port 8080

# Run multi-isolate backend server with hot restart
bloom server run --watch --port 8080

# Build production binaries
bloom build apk
bloom build ipa
bloom js build --analyze

# Deploy OTA code-push patches via Shorebird
bloom deploy --platform android
```
