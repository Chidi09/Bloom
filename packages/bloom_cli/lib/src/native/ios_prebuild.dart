// lib/src/native/ios_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

class IosPrebuild {
  final Directory iosDir;

  IosPrebuild(this.iosDir);

  /// Synchronize iOS configuration from `bloom.yaml` platforms, plugins, and deep links.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
    Map<dynamic, dynamic>? deepLinks,
  }) async {
    if (!iosDir.existsSync()) {
      return true;
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

      // Inject Deep Link URL Schemes
      if (deepLinks != null && deepLinks['enabled'] == true) {
        final schemes = deepLinks['schemes'] is List ? List<String>.from(deepLinks['schemes']) : <String>[];
        for (final scheme in schemes) {
          if (!content.contains('<string>$scheme</string>')) {
            final urlTypesBlock = '''	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>$scheme</string>
			</array>
		</dict>
	</array>
</dict>''';
            content = content.replaceFirst('</dict>', urlTypesBlock);
            print('    ${Ansi.dim}+ Injected iOS custom URL scheme: $scheme${Ansi.reset}');
          }
        }
      }

      plistFile.writeAsStringSync(content);
    }

    return true;
  }
}
