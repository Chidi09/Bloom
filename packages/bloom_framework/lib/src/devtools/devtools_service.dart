import 'dart:convert';
import 'dart:developer' as developer;
import '../core/logger.dart';
import '../data/cache.dart';
import '../router/router.dart';

/// Registers Bloom DevTools VM service extensions for live visual debugging.
class BloomDevToolsService {
  static bool _isRegistered = false;

  /// Register custom VM service extensions callable from Flutter DevTools or Bloom Go.
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
      return developer.ServiceExtensionResponse.result(jsonEncode({
        'status': 'ok',
        'hasGlobalContainer': true,
      }));
    });

    // 4. Router State Inspector
    developer.registerExtension('ext.bloom.getRouterState', (method, parameters) async {
      try {
        return developer.ServiceExtensionResponse.result(jsonEncode({
          'status': 'ok',
          'isInitialized': BloomRouter.isInitialized,
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
