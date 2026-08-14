// lib/src/native/android_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

class AndroidPrebuild {
  final Directory androidDir;

  AndroidPrebuild(this.androidDir);

  /// Synchronize Android configuration from `bloom.yaml` platforms, plugins, and deep links.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
    Map<dynamic, dynamic>? deepLinks,
  }) async {
    if (!androidDir.existsSync()) {
      return true;
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

      // 2. Inject Deep Link Intent Filters
      if (deepLinks != null && deepLinks['enabled'] == true) {
        final schemes = deepLinks['schemes'] is List ? List<String>.from(deepLinks['schemes']) : <String>[];
        final domains = deepLinks['domains'] is List ? List<String>.from(deepLinks['domains']) : <String>[];

        for (final scheme in schemes) {
          if (!content.contains('android:scheme="$scheme"')) {
            final filter = '''
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="$scheme" />
            </intent-filter>''';
            content = content.replaceFirst('</activity>', '$filter\n        </activity>');
            print('    ${Ansi.dim}+ Injected Android custom scheme intent filter: $scheme${Ansi.reset}');
          }
        }

        for (final domain in domains) {
          if (!content.contains('android:host="$domain"')) {
            final filter = '''
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="$domain" />
            </intent-filter>''';
            content = content.replaceFirst('</activity>', '$filter\n        </activity>');
            print('    ${Ansi.dim}+ Injected Android App Link intent filter: $domain${Ansi.reset}');
          }
        }
      }

      manifestFile.writeAsStringSync(content);
    }

    // 3. Update build.gradle minSdk / targetSdk if present
    final androidConfig = platforms['android'] is Map ? platforms['android'] as Map : {};
    final minSdk = androidConfig['min_sdk'] ?? androidConfig['minSdk'];
    if (minSdk != null) {
      final buildGradle = File(p.join(androidDir.path, 'app', 'build.gradle'));
      if (buildGradle.existsSync()) {
        var gradleContent = buildGradle.readAsStringSync();
        gradleContent = gradleContent.replaceAllMapped(
          RegExp(r'minSdkVersion\s+flutter\.minSdkVersion'),
          (m) => 'minSdkVersion $minSdk',
        );
        buildGradle.writeAsStringSync(gradleContent);
      }
    }

    return true;
  }
}
