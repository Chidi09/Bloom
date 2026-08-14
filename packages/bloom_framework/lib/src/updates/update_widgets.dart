// lib/src/updates/update_widgets.dart
import 'package:flutter/material.dart';
import '../state/signals.dart';
import 'bloom_updates.dart';

/// Pre-built reactive in-app update banner.
/// Automatically listens to [BloomUpdates] signals and prompts the user when updates are downloaded.
class BloomUpdateBanner extends StatelessWidget {
  final Widget? icon;
  final String readyMessage;
  final String restartButtonText;

  const BloomUpdateBanner({
    super.key,
    this.icon,
    this.readyMessage = 'A new update is ready! Restart to apply changes.',
    this.restartButtonText = 'RESTART NOW',
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (BloomUpdates.isDownloading.value) {
        final progress = BloomUpdates.downloadProgress.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress > 0 ? progress : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Downloading update (${(progress * 100).toInt()}%)...',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        );
      }

      if (BloomUpdates.isReady.value) {
        return MaterialBanner(
          leading: icon ?? const Icon(Icons.system_update_rounded),
          content: Text(readyMessage),
          actions: [
            TextButton(
              onPressed: () => BloomUpdates.reload(),
              child: Text(restartButtonText),
            ),
          ],
        );
      }

      return const SizedBox.shrink();
    });
  }
}

/// Modal dialog for mandatory or recommended OTA updates.
class BloomUpdateDialog extends StatelessWidget {
  final String title;
  final String? releaseNotes;
  final VoidCallback? onDismiss;

  const BloomUpdateDialog({
    super.key,
    this.title = 'New Update Available',
    this.releaseNotes,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final isDownloading = BloomUpdates.isDownloading.value;
      final isReady = BloomUpdates.isReady.value;
      final progress = BloomUpdates.downloadProgress.value;

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
              Text(
                'Release Notes:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(releaseNotes!),
              const SizedBox(height: 12),
            ],
            if (isDownloading) ...[
              LinearProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 8),
              Text('Downloading: ${(progress * 100).toInt()}%'),
            ] else if (isReady) ...[
              const Text('Update downloaded and verified. Restart to apply.'),
            ] else ...[
              const Text('A compatible update is available for your device.'),
            ],
          ],
        ),
        actions: [
          if (!isReady && !isDownloading && onDismiss != null)
            TextButton(
              onPressed: onDismiss,
              child: const Text('LATER'),
            ),
          if (isReady)
            ElevatedButton(
              onPressed: () => BloomUpdates.reload(),
              child: const Text('RESTART NOW'),
            )
          else if (!isDownloading)
            ElevatedButton(
              onPressed: () => BloomUpdates.fetchUpdate(),
              child: const Text('DOWNLOAD'),
            ),
        ],
      );
    });
  }
}
