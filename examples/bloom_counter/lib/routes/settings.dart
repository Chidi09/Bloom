// lib/routes/settings.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class SettingsRoute extends BloomRoute {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SettingsRoute'),
      ),
      body: const Center(
        child: Text('SettingsRoute Screen'),
      ),
    );
  }
}
