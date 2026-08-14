// lib/routes/compose.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/material.dart';
import '../controllers/feed_controller.dart';

class ComposeRoute extends StatefulWidget {
  const ComposeRoute({super.key});

  @override
  State<ComposeRoute> createState() => _ComposeRouteState();
}

class _ComposeRouteState extends State<ComposeRoute> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = inject<FeedController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                feed.addPost(text);
                context.go('/');
              }
            },
            child: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "What's happening in Bloom?",
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.indigo),
                  onPressed: () async {
                    // Simulate camera capture using Bloom native camera helper
                    final status = await BloomPermissions.check(BloomPermission.camera);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Camera permission status: ${status.name}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
