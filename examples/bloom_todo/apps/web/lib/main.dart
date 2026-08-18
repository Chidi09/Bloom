import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import 'app/boot.dart';
import 'routes/landing.dart';
import 'routes/(app)/_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebBoot.init();
  runApp(const BloomTodoWebApp());
}

class BloomTodoWebApp extends StatefulWidget {
  const BloomTodoWebApp({super.key});

  @override
  State<BloomTodoWebApp> createState() => _BloomTodoWebAppState();
}

class _BloomTodoWebAppState extends State<BloomTodoWebApp> {
  bool _inApp = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom Todo — Full-Stack Task Manager',
      debugShowCheckedModeBanner: false,
      theme: TodoTheme.dark(),
      home: _inApp
          ? const WebAppLayout()
          : LandingPage(onLaunchApp: () => setState(() => _inApp = true)),
    );
  }
}
