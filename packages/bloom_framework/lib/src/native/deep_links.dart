// lib/src/native/deep_links.dart
import 'dart:async';
import 'package:flutter/services.dart';
import '../core/logger.dart';
import '../router/router.dart';

/// Handler callback signature invoked when a deep link URI is received.
///
/// Example:
/// ```dart
/// void onLinkReceived(Uri uri) {
///   print('Received deep link: ${uri.path}');
/// }
/// ```
typedef DeepLinkHandler = FutureOr<void> Function(Uri uri);

/// Cross-platform deep linking and Universal / App Links controller.
///
/// Handles cold-start deep links (when the application is launched from a link),
/// runtime background/foreground incoming links, and automated routing via `BloomRouter`.
///
/// Example:
/// ```dart
/// await BloomDeepLinks.initialize(
///   routeMappings: {'/invite': '/auth/register'},
///   onLink: (uri) => print('Deep link: $uri'),
/// );
/// ```
class BloomDeepLinks {
  static const MethodChannel _channel = MethodChannel('bloom/deep_links');
  static const EventChannel _eventChannel = EventChannel('bloom/deep_links_events');

  static StreamSubscription<dynamic>? _linkSubscription;
  static DeepLinkHandler? _customHandler;
  static Map<String, String> _routeMappings = {};
  static Uri? _pendingInitialUri;

  /// Pending cold-start URI waiting for router creation and mounting.
  static Uri? get pendingInitialUri => _pendingInitialUri;

  /// Initializes deep link listening across cold-start and runtime event channels.
  ///
  /// Optionally configures a custom [onLink] callback handler and [routeMappings] table.
  ///
  /// Example:
  /// ```dart
  /// await BloomDeepLinks.initialize(
  ///   routeMappings: {'help': '/support'},
  /// );
  /// ```
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

  /// Resolves and navigates a deep link [uri] immediately or invokes the custom handler.
  ///
  /// Example:
  /// ```dart
  /// BloomDeepLinks.dispatch(Uri.parse('myapp://dashboard/profile?tab=settings'));
  /// ```
  static void dispatch(Uri uri) => _dispatch(uri);

  /// Drains and navigates any pending cold-start deep link buffered before the router was mounted.
  ///
  /// Invoked automatically by the Bloom router initialization lifecycle.
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

  /// Disposes and cancels active runtime deep link subscriptions.
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _customHandler = null;
    _pendingInitialUri = null;
    _routeMappings = {};
  }
}
