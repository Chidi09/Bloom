// lib/src/router/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/logger.dart';
import '../native/deep_links.dart';
import 'route.dart';

/// Central Bloom router orchestrating `GoRouter`.
class BloomRouter {
  static GoRouter? _activeGoRouter;
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'bloom_root_navigator');

  /// Whether the [GoRouter] instance has been created and mounted.
  static bool get isInitialized => _activeGoRouter != null;

  /// Get the active [GoRouter] instance.
  static GoRouter get instance {
    if (_activeGoRouter == null) {
      throw StateError(
        'BloomRouter has not been initialized. Call `BloomRouter.create(...)` or initialize via `BloomApp`.',
      );
    }
    return _activeGoRouter!;
  }

  /// Create and configure the [GoRouter] instance from route definitions and guards.
  static GoRouter create({
    required List<RouteBase> routes,
    String initialLocation = '/',
    List<BloomGuard> globalGuards = const [],
    Widget Function(BuildContext, GoRouterState)? errorBuilder,
    List<NavigatorObserver>? observers,
    bool debugLogDiagnostics = false,
  }) {
    _activeGoRouter = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: routes,
      observers: observers,
      debugLogDiagnostics: debugLogDiagnostics,
      errorBuilder: errorBuilder ?? _defaultErrorBuilder,
      redirect: (context, state) async {
        final match = BloomRouteMatch(
          location: state.uri.toString(),
          path: state.matchedLocation,
          pathParameters: state.pathParameters,
          queryParameters: state.uri.queryParameters,
          extra: state.extra,
        );

        // Run global guards
        for (final guard in globalGuards) {
          final result = await guard.canActivate(context, match);
          if (!result.isAllowed) {
            if (result.redirectPath != null) {
              logger.info('Redirecting to: ${result.redirectPath}');
              return result.redirectPath;
            }
            logger.warn('Access denied: ${result.denialMessage}');
            return '/';
          }
        }
        return null;
      },
    );

    // Drain any cold-start deep links that arrived before router creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BloomDeepLinks.drainPending();
    });

    return _activeGoRouter!;
  }

  /// Navigate to [location] replacing current stack.
  static void go(String location, {Object? extra}) {
    instance.go(location, extra: extra);
  }

  /// Push [location] onto navigation stack.
  static Future<T?> push<T>(String location, {Object? extra}) {
    return instance.push<T>(location, extra: extra);
  }

  /// Pop current route off navigation stack.
  static void pop<T>([T? result]) {
    instance.pop(result);
  }

  /// Replace current route with [location].
  static void replace(String location, {Object? extra}) {
    instance.replace(location, extra: extra);
  }

  /// Returns current route URI string.
  static String currentLocation(BuildContext context) {
    return GoRouterState.of(context).uri.toString();
  }

  /// Dump router state for DevTools inspection.
  static Map<String, dynamic> dumpRouter() {
    return {
      'isInitialized': isInitialized,
      'hasActiveGoRouter': _activeGoRouter != null,
      'pendingDeepLink': BloomDeepLinks.pendingInitialUri?.toString(),
    };
  }

  /// Helper to create a [GoRoute] with Bloom route match & guard resolution.
  static GoRoute route({
    required String path,
    required Widget Function(BuildContext context, BloomRouteMatch match) builder,
    String? name,
    List<BloomGuard> guards = const [],
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: path,
      name: name,
      routes: routes,
      redirect: (context, state) async {
        if (guards.isEmpty) return null;

        final match = BloomRouteMatch(
          location: state.uri.toString(),
          path: state.matchedLocation,
          pathParameters: state.pathParameters,
          queryParameters: state.uri.queryParameters,
          extra: state.extra,
        );

        for (final guard in guards) {
          final result = await guard.canActivate(context, match);
          if (!result.isAllowed) {
            return result.redirectPath ?? '/';
          }
        }
        return null;
      },
      builder: (context, state) {
        final match = BloomRouteMatch(
          location: state.uri.toString(),
          path: state.matchedLocation,
          pathParameters: state.pathParameters,
          queryParameters: state.uri.queryParameters,
          extra: state.extra,
        );
        return builder(context, match);
      },
    );
  }

  /// Helper to create a nested persistent tab / shell route.
  static ShellRoute shell({
    required Widget Function(BuildContext context, GoRouterState state, Widget child) builder,
    required List<RouteBase> routes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return ShellRoute(
      navigatorKey: navigatorKey,
      builder: builder,
      routes: routes,
    );
  }

  /// Default error builder for unhandled routes (404).
  static Widget _defaultErrorBuilder(BuildContext context, GoRouterState state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '404 - Not Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('No route registered for: ${state.uri}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => go('/'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
