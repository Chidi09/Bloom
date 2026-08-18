import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';

class ProjectCalendarPage extends StatelessWidget {
  final String projectId;

  const ProjectCalendarPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Calendar', style: TodoTypography.h3),
      ),
      body: Center(
        child: Text('6-Week Calendar Grid View', style: TodoTypography.bodyMedium),
      ),
    );
  }
}
