# Bloom Framework

[![pub package](https://img.shields.io/pub/v/bloom_framework.svg)](https://pub.dev/packages/bloom_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

> **"Flutter gives you the engine. Bloom gives you the application framework."**

Bloom is an opinionated application framework and developer platform built on Dart and Flutter. It unifies state management, filesystem routing, server-state query caching, offline mutation queueing, declarative native plugins, and full-stack API routes into a single cohesive foundation.

---

## 🌟 Core Features

* **⚡ Signals State Management**: Fine-grained, zero-boilerplate reactivity powered by Signals.
* **📁 Filesystem Routing**: Next.js-inspired file-based routing compiled to `go_router`.
* **💾 Bloom Data & Offline Sync**: Stale-while-revalidate asynchronous caching with automatic offline mutation replay.
* **📱 Native Integration**: Zero-config declarative native plugins for storage, permissions, camera, notifications, and deep links.
* **🌐 Full-Stack Web & SSR**: Unified client + server runtime with API routes (`routes/api/*`) and SSR hydration.
* **🔍 In-App DevTools & Observability**: Real-time request inspection, replay engine, and automatic crash telemetry.

---

## 🚀 Quickstart

```dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';

void main() async {
  await Bloom.boot(
    environment: 'development',
    config: BloomAppConfig(name: 'my_app', version: '1.0.0'),
  );

  runApp(const MaterialApp(
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Bloom App')),
      body: Center(
        child: Watch((context) => Text('Counter: ${count.value}', style: const TextStyle(fontSize: 24))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## 📚 Documentation

For complete documentation, guides, and full-stack recipes, visit the [Bloom Documentation Portal](https://github.com/bloom-framework/bloom/tree/main/docs).
