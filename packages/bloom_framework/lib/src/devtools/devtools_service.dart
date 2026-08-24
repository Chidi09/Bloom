/// VM service extension registration service for Flutter DevTools and Bloom Go.
library;

import 'dart:convert';
import 'dart:developer' as developer;
import '../core/boot.dart';
import '../core/logger.dart';
import '../data/cache.dart';
import '../di/container.dart';
import '../router/router.dart';

/// Registers Bloom DevTools VM service extensions for live visual debugging.
///
/// Enables inspecting query caches, the DI container, routing state, and runtime configurations
/// from Flutter DevTools, VS Code, or Bloom Go mobile app.
///
/// Example:
/// ```dart
/// BloomDevToolsService.register();
/// ```
class BloomDevToolsService {
  static bool _isRegistered = false;

  /// Registers custom VM service extensions (`ext.bloom.*`) callable from DevTools or Bloom Go.
  static void register() {

    if (_isRegistered) return;
    _isRegistered = true;

    // 1. Query Cache Inspector
    developer.registerExtension('ext.bloom.getQueryCache', (method, parameters) async {
      try {
        final cacheDump = BloomData.dumpCache();
        return developer.ServiceExtensionResponse.result(jsonEncode({
          'status': 'ok',
          'cache': cacheDump,
          'count': BloomData.entryCount,
          'timestamp': DateTime.now().toIso8601String(),
        }));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // 2. Clear Query Cache
    developer.registerExtension('ext.bloom.clearCache', (method, parameters) async {
      BloomData.clear();
      return developer.ServiceExtensionResponse.result(jsonEncode({
        'status': 'ok',
        'message': 'Bloom cache cleared successfully',
      }));
    });

    // 3. DI Container Inspector
    developer.registerExtension('ext.bloom.getContainerInfo', (method, parameters) async {
      try {
        final containerDump = globalContainer.dumpContainer();
        return developer.ServiceExtensionResponse.result(jsonEncode({
          'status': 'ok',
          'container': containerDump,
        }));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // 4. Router State Inspector
    developer.registerExtension('ext.bloom.getRouterState', (method, parameters) async {
      try {
        final routerDump = BloomRouter.dumpRouter();
        return developer.ServiceExtensionResponse.result(jsonEncode({
          'status': 'ok',
          'router': routerDump,
        }));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // 5. Config Inspector
    developer.registerExtension('ext.bloom.getConfig', (method, parameters) async {
      try {
        final config = Bloom.config;
        return developer.ServiceExtensionResponse.result(jsonEncode({
          'status': 'ok',
          'name': config.name,
          'version': config.version,
          'mode': config.mode,
          'activeFlavor': Bloom.activeFlavor,
        }));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    logger.debug('BloomDevToolsService: Registered Bloom VM service extensions.');
  }
}
