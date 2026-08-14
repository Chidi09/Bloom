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
  static Map<String, String> _routeMappings = {};
  static Uri? _pendingInitialUri;

  /// Pending cold-start URI waiting for router creation.
  static Uri? get pendingInitialUri => _pendingInitialUri;

  /// Initialize deep link listening.
  static Future<void> initialize({
    DeepLinkHandler? onLink,
    Map<String, String> routeMappings = const {},
  }) async {
    _customHandler = onLink;
    _routeMappings = routeMappings;

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

  /// Resolve and navigate a deep link URI.
  static void dispatch(Uri uri) => _dispatch(uri);

  /// Drain and navigate pending cold-start deep link once router is mounted.
  static void drainPending() {
    if (_pendingInitialUri != null) {
      final uri = _pendingInitialUri!;
      _pendingInitialUri = null;
      _dispatch(uri);
    }
  }

  static void _dispatch(Uri uri) {
    if (_customHandler != null) {
      _customHandler!(uri);
      return;
    }

    // 1. Check configurable host->route mappings
    final hostAndPath = '${uri.host}${uri.path}';
    String? targetPath;

    for (final entry in _routeMappings.entries) {
      if (entry.key == hostAndPath || entry.key == uri.path || entry.key == uri.host) {
        targetPath = entry.value;
        break;
      }
    }

    // 2. Default to uri.path if no specific mapping matched
    targetPath ??= uri.path.isNotEmpty ? uri.path : '/';

    if (uri.hasQuery) {
      targetPath = targetPath.contains('?')
          ? '$targetPath&${uri.query}'
          : '$targetPath?${uri.query}';
    }

    // 3. Safe navigation with cold-start buffering
    if (BloomRouter.isInitialized) {
      try {
        logger.info('BloomDeepLinks: Navigating to $targetPath');
        BloomRouter.go(targetPath);
      } catch (e) {
        logger.error('BloomDeepLinks: Failed to navigate to $targetPath: $e');
      }
    } else {
      logger.info('BloomDeepLinks: Router not yet mounted. Buffering initial link: $uri');
      _pendingInitialUri = uri;
    }
  }

  /// Dispose and cancel active link subscriptions.
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _customHandler = null;
    _pendingInitialUri = null;
    _routeMappings = {};
  }
}
