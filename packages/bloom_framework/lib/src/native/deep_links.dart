// lib/src/native/deep_links.dart
import 'dart:async';
import 'package:flutter/services.dart';
import '../core/logger.dart';
import '../router/router.dart';

typedef DeepLinkHandler = FutureOr<void> Function(Uri uri);

/// Cross-platform deep linking and Universal / App Links controller.
class BloomDeepLinks {
  static const MethodChannel _channel = MethodChannel('bloom/deep_links');
  static const EventChannel _eventChannel = EventChannel('bloom/deep_links_events');

  static StreamSubscription<dynamic>? _linkSubscription;
  static DeepLinkHandler? _customHandler;

  /// Initialize deep link listening. Automatically navigates via [BloomRouter] unless [onLink] is provided.
  static Future<void> initialize({DeepLinkHandler? onLink}) async {
    _customHandler = onLink;

    // 1. Get initial launch deep link (cold start)
    try {
      final initialLinkStr = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLinkStr != null && initialLinkStr.isNotEmpty) {
        final uri = Uri.tryParse(initialLinkStr);
        if (uri != null) {
          logger.info('BloomDeepLinks: App cold-started with deep link: $uri');
          _dispatch(uri);
        }
      }
    } catch (_) {}

    // 2. Listen to incoming foreground/background links
    try {
      _linkSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic link) {
          if (link is String && link.isNotEmpty) {
            final uri = Uri.tryParse(link);
            if (uri != null) {
              logger.info('BloomDeepLinks: Received runtime deep link: $uri');
              _dispatch(uri);
            }
          }
        },
        onError: (err) {
          logger.warn('BloomDeepLinks: Event channel error: $err');
        },
      );
    } catch (_) {}
  }

  /// Manually dispatch and process a deep link URI.
  static void dispatch(Uri uri) => _dispatch(uri);

  static void _dispatch(Uri uri) {
    if (_customHandler != null) {
      _customHandler!(uri);
      return;
    }

    // Default: route path + query parameters
    var targetPath = uri.path;
    if (targetPath.isEmpty) targetPath = '/';
    if (uri.hasQuery) {
      targetPath = '$targetPath?${uri.query}';
    }

    try {
      logger.info('BloomDeepLinks: Navigating to $targetPath');
      BloomRouter.go(targetPath);
    } catch (e) {
      logger.error('BloomDeepLinks: Failed to navigate to $targetPath: $e');
    }
  }

  /// Dispose and cancel active link subscriptions.
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _customHandler = null;
  }
}
