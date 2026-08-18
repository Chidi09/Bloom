import 'package:flutter/material.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';

class WorkspaceSettingsDialog extends StatelessWidget {
  const WorkspaceSettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const WorkspaceSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: BloomCard(
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF27272A),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Workspace Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF71717A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Workspace Info
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.currentWorkspace.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          const Text('Pro Team • 8 Isolates', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                        ],
                      ),
                    ),
                    const BloomBadge(
                      variant: BloomBadgeVariant.defaultVariant,
                      child: Text('ACTIVE'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const BloomSeparator(),
                const SizedBox(height: 16),

                // Team Members (4)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Team Members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    BloomButton(
                      size: BloomButtonSize.xs,
                      variant: BloomButtonVariant.outline,
                      onPressed: () {},
                      child: const Text('+ Invite'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMemberRow('Alex Rivers (You)', 'Owner', true),
                _buildMemberRow('David Chen', 'Admin', true),
                _buildMemberRow('Elena Rostova', 'Editor', true),
                _buildMemberRow('Sarah Miller', 'Editor', false),

                const SizedBox(height: 20),
                const BloomSeparator(),
                const SizedBox(height: 16),

                // Cluster Health Telemetry
                const Text('Cluster Nodes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('8 AOT Isolate Workers', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA))),
                      Text('100% Healthy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildMemberRow(String name, String role, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          BloomAvatar(name: name, size: BloomAvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white))),
          Text(role, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? const Color(0xFF10B981) : const Color(0xFF71717A)),
          ),
        ],
      ),
    );
  }
}
