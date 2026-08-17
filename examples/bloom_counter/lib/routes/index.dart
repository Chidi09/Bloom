// lib/routes/index.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class IndexRoute extends BloomRoute {
  const IndexRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);

    return Scaffold(
      appBar: AppBar(
        title: Text(Bloom.config.name),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BloomLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'Welcome to Bloom',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Environment: ${BloomEnv.get('APP_ENV', defaultValue: 'local')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 32),
            Watch((context) {
              return Text(
                'Clicks: ${count.value}',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => count.value++,
              icon: const Icon(Icons.add),
              label: const Text('Increment Signal'),
            ),
          ],
        ),
      ),
    );
  }
}
