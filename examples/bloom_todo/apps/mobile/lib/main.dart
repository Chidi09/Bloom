import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';

import 'app/boot.dart';
import 'app/router.dart';

/// Entry point for the Bloom Todo mobile app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BloomBoot.init();
  runApp(const BloomTodoApp());
}

/// Root application widget.
class BloomTodoApp extends StatelessWidget {
  const BloomTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bloom Todo',
      debugShowCheckedModeBanner: kDebugMode,
      theme: TodoTheme.light(),
      darkTheme: TodoTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
