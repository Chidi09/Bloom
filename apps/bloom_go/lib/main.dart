// lib/main.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/routes.g.dart';

void main() async {
  await Bloom.boot();
  BloomDevToolsService.register();
  runApp(const BloomGoApp());
}

class BloomGoApp extends StatelessWidget {
  const BloomGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BloomApp(
      title: 'Bloom Go',
      routes: $bloomRoutes,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
    );
  }
}
