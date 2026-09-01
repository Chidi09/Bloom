/// Pre-built reactive UI widgets for displaying in-app OTA update status and prompts.
library;

import 'package:flutter/widgets.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;
import '../state/signals.dart';
import 'bloom_updates.dart';

/// Pre-built reactive in-app update banner.
///
/// Automatically listens to [BloomUpdates] signals and prompts the user when updates are downloaded and ready.
///
/// Example:
/// ```dart
/// ui.BloomScaffold(
///   header: Container(
///     padding: const EdgeInsets.all(16),
///     child: const Text('My App'),
///   ),
///   body: Column(
///     children: [
///       const BloomUpdateBanner(),
///       Expanded(child: MainContent()),
///     ],
///   ),
/// );
/// ```
class BloomUpdateBanner extends StatelessWidget {
  /// Optional leading icon widget.
  final Widget? icon;

  /// Message displayed when an update is staged and ready to apply.
  final String readyMessage;

  /// Button label for triggering app reload.
  final String restartButtonText;

  /// Creates a [BloomUpdateBanner].
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
        final colors = context.bloomColors;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colors.secondary,
          child: Row(
            children: [
              ui.BloomSpinner(
                size: 18,
                strokeWidth: 2.5,
                color: colors.secondaryForeground,
                value: progress > 0 ? progress : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Downloading update (${(progress * 100).toInt()}%)...',
                  style: TextStyle(color: colors.secondaryForeground),
                ),
              ),
            ],
          ),
        );
      }

      if (BloomUpdates.isReady.value) {
        return ui.BloomBanner(
          leading: icon ?? const ui.BloomIcon(ui.BloomIcons.systemUpdate),
          message: readyMessage,
          actions: [
            ui.BloomButton(
              variant: ui.BloomButtonVariant.ghost,
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
///
/// Displays release notes, a download progress indicator, and action buttons.
///
/// Example:
/// ```dart
/// ui.showBloomDialog(
///   context: context,
///   builder: (_) => const BloomUpdateDialog(
///     title: 'Version 2.0 Available',
///     releaseNotes: '- Performance upgrades\n- UI fixes',
///   ),
/// );
/// ```
class BloomUpdateDialog extends StatelessWidget {
  /// Dialog title text.
  final String title;

  /// Optional release notes markdown or summary string.
  final String? releaseNotes;

  /// Optional dismiss callback for optional updates.
  final VoidCallback? onDismiss;

  /// Creates a [BloomUpdateDialog].
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

      return ui.BloomDialog(
        showClose: false,
        header: ui.BloomDialogHeader(
          title: ui.BloomDialogTitle(title),
        ),
        content: ui.BloomDialogContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                const Text(
                  'Release Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(releaseNotes!),
                const SizedBox(height: 12),
              ],
              if (isDownloading) ...[
                ui.BloomProgress(value: progress > 0 ? progress : null),
                const SizedBox(height: 8),
                Text('Downloading: ${(progress * 100).toInt()}%'),
              ] else if (isReady) ...[
                const Text('Update downloaded and verified. Restart to apply.'),
              ] else ...[
                const Text('A compatible update is available for your device.'),
              ],
            ],
          ),
        ),
        footer: ui.BloomDialogFooter(
          actions: [
            if (!isReady && !isDownloading && onDismiss != null)
              ui.BloomButton(
                variant: ui.BloomButtonVariant.outline,
                onPressed: onDismiss,
                child: const Text('LATER'),
              ),
            if (isReady)
              ui.BloomButton(
                variant: ui.BloomButtonVariant.defaultVariant,
                onPressed: () => BloomUpdates.reload(),
                child: const Text('RESTART NOW'),
              )
            else if (!isDownloading)
              ui.BloomButton(
                variant: ui.BloomButtonVariant.defaultVariant,
                onPressed: () => BloomUpdates.fetchUpdate(),
                child: const Text('DOWNLOAD'),
              ),
          ],
        ),
      );
    });
  }
}
