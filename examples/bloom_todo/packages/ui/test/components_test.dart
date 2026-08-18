import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';

void main() {
  testWidgets('TaskTile renders title and priority checkbox', (tester) async {
    final task = Task(
      id: 'tsk_1',
      projectId: 'prj_1',
      workspaceId: 'ws_1',
      creatorId: 'usr_1',
      title: 'Design Bloom Todo architecture',
      priority: Priority.p1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: TodoTheme.dark(),
        home: Scaffold(
          body: TaskTile(
            task: task,
            onToggleComplete: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Design Bloom Todo architecture'), findsOneWidget);

    // Tap BloomCheckbox to toggle
    await tester.tap(find.byType(BloomCheckbox));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('PrioritySelector renders 4 priority flags', (tester) async {
    Priority selected = Priority.p4;

    await tester.pumpWidget(
      MaterialApp(
        theme: TodoTheme.dark(),
        home: Scaffold(
          body: PrioritySelector(
            selected: selected,
            onChanged: (p) => selected = p,
          ),
        ),
      ),
    );

    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('P4'), findsOneWidget);
  });
}
