// lib/main.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';
import 'routes/api/health.dart';
import 'routes/api/users.dart';
import 'routes/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Server API Router
  final apiRouter = BloomApiRouter();
  apiRouter.get('/api/health', handleHealth);
  apiRouter.get('/api/users', handleGetUsers);
  apiRouter.post('/api/users', handleCreateUser);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const IndexRoute(),
      ),
    ],
  );

  runApp(BloomFullstackApp(router: router));
}

class BloomFullstackApp extends StatelessWidget {
  final GoRouter router;
  const BloomFullstackApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bloom FullStack App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
