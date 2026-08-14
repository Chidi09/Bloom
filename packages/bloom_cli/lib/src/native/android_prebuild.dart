// lib/src/native/android_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

class AndroidPrebuild {
  final Directory androidDir;

  AndroidPrebuild(this.androidDir);

  /// Synchronize Android configuration from `bloom.yaml` platforms & plugins.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
  }) async {
    if (!androidDir.existsSync()) {
      return true; // No android platform in this project
    }

    print(Ansi.step('  Android: Synchronizing AndroidManifest.xml & Gradle configuration...'));

    // 1. AndroidManifest.xml update
    final manifestFile = File(
      p.join(androidDir.path, 'app', 'src', 'main', 'AndroidManifest.xml'),
    );

    if (manifestFile.existsSync()) {
      var content = manifestFile.readAsStringSync();
      final permissionsToInject = <String>{};

      // Always include Internet
      permissionsToInject.add('android.permission.INTERNET');

      // Detect plugins
      for (final plugin in plugins) {
        final pluginName = plugin is String ? plugin : (plugin is Map ? plugin.keys.first.toString() : '');
        if (pluginName == 'camera') {
          permissionsToInject.add('android.permission.CAMERA');
          permissionsToInject.add('android.permission.RECORD_AUDIO');
        } else if (pluginName == 'notifications') {
          permissionsToInject.add('android.permission.POST_NOTIFICATIONS');
          permissionsToInject.add('android.permission.VIBRATE');
        } else if (pluginName == 'location') {
          permissionsToInject.add('android.permission.ACCESS_FINE_LOCATION');
          permissionsToInject.add('android.permission.ACCESS_COARSE_LOCATION');
        }
      }

      // Inject missing permissions right before <application
      for (final perm in permissionsToInject) {
        final permXml = '<uses-permission android:name="$perm" />';
        if (!content.contains(perm)) {
          if (content.contains('<application')) {
            content = content.replaceFirst('<application', '    $permXml\n    <application');
            print('    ${Ansi.dim}+ Injected Android permission: $perm${Ansi.reset}');
          }
        }
      }

      manifestFile.writeAsStringSync(content);
    }

    return true;
  }
}
