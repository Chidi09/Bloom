// lib/src/native/ios_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

class IosPrebuild {
  final Directory iosDir;

  IosPrebuild(this.iosDir);

  /// Synchronize iOS configuration from `bloom.yaml` platforms & plugins.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
  }) async {
    if (!iosDir.existsSync()) {
      return true; // No ios platform in this project
    }

    print(Ansi.step('  iOS: Synchronizing Info.plist & project permissions...'));

    final plistFile = File(p.join(iosDir.path, 'Runner', 'Info.plist'));
    if (plistFile.existsSync()) {
      var content = plistFile.readAsStringSync();
      final keysToInject = <String, String>{};

      for (final plugin in plugins) {
        final pluginName = plugin is String ? plugin : (plugin is Map ? plugin.keys.first.toString() : '');
        final pluginConfig = plugin is Map ? plugin[pluginName] as Map? : null;

        if (pluginName == 'camera') {
          keysToInject['NSCameraUsageDescription'] = pluginConfig?['camera_permission']?.toString() ??
              'This application requires camera access to take photos.';
          keysToInject['NSMicrophoneUsageDescription'] = pluginConfig?['microphone_permission']?.toString() ??
              'This application requires microphone access to record audio.';
        } else if (pluginName == 'location') {
          keysToInject['NSLocationWhenInUseUsageDescription'] =
              'This application requires location access to provide location services.';
        }
      }

      // Inject keys before </dict>
      for (final entry in keysToInject.entries) {
        if (!content.contains('<key>${entry.key}</key>')) {
          final xmlBlock = '	<key>${entry.key}</key>\n	<string>${entry.value}</string>\n</dict>';
          content = content.replaceFirst('</dict>', xmlBlock);
          print('    ${Ansi.dim}+ Injected iOS Info.plist key: ${entry.key}${Ansi.reset}');
        }
      }

      plistFile.writeAsStringSync(content);
    }

    return true;
  }
}
