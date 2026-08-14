// lib/src/native/ios_prebuild.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../utils/ansi.dart';

class IosPrebuild {
  final Directory iosDir;

  IosPrebuild(this.iosDir);

  /// Synchronize iOS configuration from `bloom.yaml` platforms, plugins, and deep links using XML AST manipulation.
  Future<bool> synchronize({
    required Map<dynamic, dynamic> platforms,
    required List<dynamic> plugins,
    Map<dynamic, dynamic>? deepLinks,
  }) async {
    if (!iosDir.existsSync()) {
      return true;
    }

    print(Ansi.step('  iOS: Synchronizing Info.plist (XML AST) & project permissions...'));

    final plistFile = File(p.join(iosDir.path, 'Runner', 'Info.plist'));
    if (plistFile.existsSync()) {
      try {
        final xmlDoc = XmlDocument.parse(plistFile.readAsStringSync());
        final rootDict = xmlDoc.findAllElements('dict').firstOrNull;

        if (rootDict != null) {
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

          // Extract existing keys in the root dictionary
          final existingKeys = <String>{};
          for (final keyNode in rootDict.findElements('key')) {
            existingKeys.add(keyNode.innerText.trim());
          }

          // Inject missing permission keys
          for (final entry in keysToInject.entries) {
            if (!existingKeys.contains(entry.key)) {
              rootDict.children.add(XmlElement(XmlName('key'), [], [XmlText(entry.key)]));
              rootDict.children.add(XmlElement(XmlName('string'), [], [XmlText(entry.value)]));
              print('    ${Ansi.dim}+ Injected iOS Info.plist key: ${entry.key}${Ansi.reset}');
            }
          }

          // Inject Deep Link URL Schemes
          if (deepLinks != null && deepLinks['enabled'] == true) {
            final schemes = deepLinks['schemes'] is List ? List<String>.from(deepLinks['schemes']) : <String>[];
            if (schemes.isNotEmpty) {
              if (!existingKeys.contains('CFBundleURLTypes')) {
                final urlTypesKey = XmlElement(XmlName('key'), [], [XmlText('CFBundleURLTypes')]);
                final arrayNode = XmlElement(XmlName('array'), [], [
                  XmlElement(XmlName('dict'), [], [
                    XmlElement(XmlName('key'), [], [XmlText('CFBundleTypeRole')]),
                    XmlElement(XmlName('string'), [], [XmlText('Editor')]),
                    XmlElement(XmlName('key'), [], [XmlText('CFBundleURLSchemes')]),
                    XmlElement(XmlName('array'), [], schemes.map((s) => XmlElement(XmlName('string'), [], [XmlText(s)]))),
                  ]),
                ]);
                rootDict.children.add(urlTypesKey);
                rootDict.children.add(arrayNode);
                for (final s in schemes) {
                  print('    ${Ansi.dim}+ Injected iOS custom URL scheme: $s${Ansi.reset}');
                }
              }
            }
          }

          plistFile.writeAsStringSync(xmlDoc.toXmlString(pretty: true, indent: '\t'));
        }
      } catch (e) {
        print(Ansi.warn('IosPrebuild: XML plist parsing note: $e'));
      }
    }

    return true;
  }
}
