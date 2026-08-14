// lib/src/native/android_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../utils/ansi.dart';

class AndroidPrebuild {
  final Directory androidDir;

  AndroidPrebuild(this.androidDir);

  /// Synchronize Android configuration using XML AST manipulation and Gradle synchronization.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
    Map<dynamic, dynamic>? deepLinks,
  }) async {
    if (!androidDir.existsSync()) {
      return true;
    }

    print(Ansi.step('  Android: Synchronizing AndroidManifest.xml (XML AST) & Gradle configuration...'));

    // 1. AndroidManifest.xml synchronization via XML parser
    final manifestFile = File(
      p.join(androidDir.path, 'app', 'src', 'main', 'AndroidManifest.xml'),
    );

    if (manifestFile.existsSync()) {
      try {
        final xmlDoc = XmlDocument.parse(manifestFile.readAsStringSync());
        final manifestNode = xmlDoc.findElements('manifest').firstOrNull;

        if (manifestNode != null) {
          final permissionsToInject = <String>{};
          permissionsToInject.add('android.permission.INTERNET');

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

          // Check existing permissions in XML
          final existingPerms = manifestNode
              .findElements('uses-permission')
              .map((node) => node.getAttribute('android:name'))
              .whereType<String>()
              .toSet();

          for (final perm in permissionsToInject) {
            if (!existingPerms.contains(perm)) {
              final permElement = XmlElement(
                XmlName('uses-permission'),
                [XmlAttribute(XmlName('android:name'), perm)],
              );
              // Insert before <application>
              final appNode = manifestNode.findElements('application').firstOrNull;
              if (appNode != null) {
                final appIndex = manifestNode.children.indexOf(appNode);
                manifestNode.children.insert(appIndex, permElement);
              } else {
                manifestNode.children.add(permElement);
              }
              print('    ${Ansi.dim}+ Injected Android permission: $perm${Ansi.reset}');
            }
          }

          // 2. Inject Deep Link Intent Filters inside main <activity>
          if (deepLinks != null && deepLinks['enabled'] == true) {
            final appNode = manifestNode.findElements('application').firstOrNull;
            final activityNode = appNode?.findElements('activity').firstOrNull;

            if (activityNode != null) {
              final schemes = deepLinks['schemes'] is List ? List<String>.from(deepLinks['schemes']) : <String>[];
              final rawDomains = deepLinks['domains'] is List ? deepLinks['domains'] as List : [];
              final domainStrings = <String>[];

              for (final d in rawDomains) {
                if (d is String) {
                  domainStrings.add(d);
                } else if (d is Map && d['host'] != null) {
                  domainStrings.add(d['host'].toString());
                }
              }

              final existingSchemes = <String>{};
              for (final intentFilter in activityNode.findElements('intent-filter')) {
                for (final dataNode in intentFilter.findElements('data')) {
                  final scheme = dataNode.getAttribute('android:scheme');
                  if (scheme != null) existingSchemes.add(scheme);
                }
              }

              for (final scheme in schemes) {
                if (!existingSchemes.contains(scheme)) {
                  final intentFilter = XmlElement(
                    XmlName('intent-filter'),
                    [],
                    [
                      XmlElement(XmlName('action'), [XmlAttribute(XmlName('android:name'), 'android.intent.action.VIEW')]),
                      XmlElement(XmlName('category'), [XmlAttribute(XmlName('android:name'), 'android.intent.category.DEFAULT')]),
                      XmlElement(XmlName('category'), [XmlAttribute(XmlName('android:name'), 'android.intent.category.BROWSABLE')]),
                      XmlElement(XmlName('data'), [XmlAttribute(XmlName('android:name'), scheme)]),
                    ],
                  );
                  activityNode.children.add(intentFilter);
                  print('    ${Ansi.dim}+ Injected Android custom scheme intent filter: $scheme${Ansi.reset}');
                }
              }

              for (final domain in domainStrings) {
                final intentFilter = XmlElement(
                  XmlName('intent-filter'),
                  [XmlAttribute(XmlName('android:autoVerify'), 'true')],
                  [
                    XmlElement(XmlName('action'), [XmlAttribute(XmlName('android:name'), 'android.intent.action.VIEW')]),
                    XmlElement(XmlName('category'), [XmlAttribute(XmlName('android:name'), 'android.intent.category.DEFAULT')]),
                    XmlElement(XmlName('category'), [XmlAttribute(XmlName('android:name'), 'android.intent.category.BROWSABLE')]),
                    XmlElement(XmlName('data'), [
                      XmlAttribute(XmlName('android:scheme'), 'https'),
                      XmlAttribute(XmlName('android:host'), domain),
                    ]),
                  ],
                );
                activityNode.children.add(intentFilter);
                print('    ${Ansi.dim}+ Injected Android App Link intent filter: $domain${Ansi.reset}');
              }
            }
          }

          manifestFile.writeAsStringSync(xmlDoc.toXmlString(pretty: true, indent: '    '));
        }
      } catch (e) {
        print(Ansi.warn('AndroidPrebuild: XML manifest parsing note: $e'));
      }
    }

    // 3. Update build.gradle and build.gradle.kts for minSdk and targetSdk
    final androidConfig = platforms['android'] is Map ? platforms['android'] as Map : {};
    final minSdk = androidConfig['min_sdk'] ?? androidConfig['minSdk'];
    final targetSdk = androidConfig['target_sdk'] ?? androidConfig['targetSdk'];

    // Groovy build.gradle
    final buildGradle = File(p.join(androidDir.path, 'app', 'build.gradle'));
    if (buildGradle.existsSync()) {
      var content = buildGradle.readAsStringSync();
      if (minSdk != null) {
        content = content.replaceAll(RegExp(r'minSdkVersion\s+.*'), 'minSdkVersion $minSdk');
      }
      if (targetSdk != null) {
        content = content.replaceAll(RegExp(r'targetSdkVersion\s+.*'), 'targetSdkVersion $targetSdk');
      }
      buildGradle.writeAsStringSync(content);
    }

    // Kotlin DSL build.gradle.kts
    final buildGradleKts = File(p.join(androidDir.path, 'app', 'build.gradle.kts'));
    if (buildGradleKts.existsSync()) {
      var content = buildGradleKts.readAsStringSync();
      if (minSdk != null) {
        content = content.replaceAll(RegExp(r'minSdk\s*=.*'), 'minSdk = $minSdk');
      }
      if (targetSdk != null) {
        content = content.replaceAll(RegExp(r'targetSdk\s*=.*'), 'targetSdk = $targetSdk');
      }
      buildGradleKts.writeAsStringSync(content);
    }

    return true;
  }
}
