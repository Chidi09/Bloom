// lib/main.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';
import 'controllers/feed_controller.dart';
import 'routes/compose.dart';
import 'routes/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register feed state controller
  provideSingleton<FeedController>(() => FeedController());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const IndexRoute(),
      ),
      GoRoute(
        path: '/compose',
        builder: (context, state) => const ComposeRoute(),
      ),
    ],
  );

  runApp(BloomSocialApp(router: router));
}

class BloomSocialApp extends StatelessWidget {
  final GoRouter router;
  const BloomSocialApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bloom Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
