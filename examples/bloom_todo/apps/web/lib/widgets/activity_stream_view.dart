import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class ActivityStreamView extends StatelessWidget {
  const ActivityStreamView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: store.activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = store.activities[index];
        final timeAgo = _formatTimeAgo(item.createdAt);

        return BloomCard(
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF22222A),
          child: Row(
            children: [
              const BloomAvatar(name: 'Alex Rivers', size: BloomAvatarSize.sm),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.body ?? 'Activity event logged',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
            ],
          ),
        );
      },
    );
  }

  static String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
