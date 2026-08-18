import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class TelemetryPanelView extends StatelessWidget {
  const TelemetryPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E12),
        border: Border(left: BorderSide(color: Color(0xFF1E1E24))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live Reactive Karma & Daily Goal
          BloomCard(
            backgroundColor: const Color(0xFF14141A),
            borderColor: const Color(0xFF22222A),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Productivity Karma', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    BloomBadge(
                      variant: BloomBadgeVariant.defaultVariant,
                      size: BloomBadgeSize.sm,
                      child: Text('${store.karmaScore}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KarmaRing(score: store.karmaScore, size: 72),
                const SizedBox(height: 12),
                Text(
                  'Daily Goal: ${store.completedTodayCount} / ${store.dailyGoal} Tasks',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 8),
                BloomProgress(value: store.todayProgress),
                const SizedBox(height: 8),
                const Text(
                  '7-day completion streak',
                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cluster Node Telemetry
          BloomCard(
            backgroundColor: const Color(0xFF14141A),
            borderColor: const Color(0xFF22222A),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Cluster Telemetry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 12),
                _TelemetryRow(label: 'Active Isolates', value: '8 Workers', color: Color(0xFF6366F1)),
                _TelemetryRow(label: 'P99 Latency', value: '1.24 ms', color: Color(0xFF10B981)),
                _TelemetryRow(label: 'SQLite Engine', value: 'WAL 32MB', color: Color(0xFFF59E0B)),
                _TelemetryRow(label: 'OTA Channel', value: 'production', color: Color(0xFFEC4899)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Team Members
          const BloomCard(
            backgroundColor: Color(0xFF14141A),
            borderColor: Color(0xFF22222A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workspace Team (4)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 12),
                _TeamMemberRow(name: 'Alex Rivers', isOnline: true),
                _TeamMemberRow(name: 'David Chen', isOnline: true),
                _TeamMemberRow(name: 'Elena Rostova', isOnline: true),
                _TeamMemberRow(name: 'Sarah Miller', isOnline: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TelemetryRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _TeamMemberRow({required this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          BloomAvatar(name: name, size: BloomAvatarSize.sm),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xFF10B981) : const Color(0xFF71717A),
            ),
          ),
        ],
      ),
    );
  }
}
