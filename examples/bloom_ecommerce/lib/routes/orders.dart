// lib/routes/orders.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';

class OrdersRoute extends StatelessWidget {
  const OrdersRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingCount = OfflineMutationQueue.pendingCount;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.deepPurple[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.cloud_sync, size: 36, color: Colors.deepPurple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bloom Offline Sync Status',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text('Pending Offline Mutations: $pendingCount'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: const Text('Order #10492'),
                  subtitle: const Text('2 items • Total: \$848.99'),
                  trailing: const Text('Confirmed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.sync, color: Colors.white),
                  ),
                  title: const Text('Order #10493 (Offline Queue)'),
                  subtitle: const Text('1 item • Total: \$149.99'),
                  trailing: const Text('Synced', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
