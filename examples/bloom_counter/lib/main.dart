// lib/main.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/boot.dart';
import 'app/routes.g.dart';

Future<void> main() async {
  // Initialize Bloom runtime, environment, and dependency injection
  await Bloom.boot(
    bootstrapper: const AppBootstrapper(),
  );

  runApp(
    BloomApp(
      title: Bloom.config.name,
      routerConfig: appRouter,
    ),
  );
}
