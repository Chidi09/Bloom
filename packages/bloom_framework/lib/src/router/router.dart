/// Central Bloom router orchestrating `GoRouter` navigation and route guards.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/logger.dart';
import '../native/deep_links.dart';
import 'route.dart';

/// Central Bloom router orchestrating declarative navigation, deep links, and route guards.
///
/// Wraps `GoRouter` with Bloom guard execution, type-safe navigation helpers,
/// and DevTools inspection capabilities.
///
/// Example:
/// ```dart
/// final router = BloomRouter.create(
///   routes: [
///     BloomRouter.route(
///       path: '/',
///       builder: (context, match) => const HomeScreen(),
///     ),
///   ],
/// );
/// ```
class BloomRouter {
  static GoRouter? _activeGoRouter;

  /// Global navigator key attached to the root Flutter [Navigator].
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'bloom_root_navigator');

  /// Whether the [GoRouter] instance has been created and mounted.
  static bool get isInitialized => _activeGoRouter != null;

  /// Get the active [GoRouter] instance.
  ///
  /// Throws [StateError] if [BloomRouter.create] has not been called.
  static GoRouter get instance {
    if (_activeGoRouter == null) {
      throw StateError(
        'BloomRouter has not been initialized. Call `BloomRouter.create(...)` or initialize via `BloomApp`.',
      );
    }
    return _activeGoRouter!;
  }

  /// Creates and configures the [GoRouter] instance from route definitions and guards.
  ///
  /// Parameters:
  /// - [routes]: List of route definitions ([GoRoute], [ShellRoute], etc.).
  /// - [initialLocation]: Starting URL path (defaults to `'/'`).
  /// - [globalGuards]: Guards executed on every navigation event before route resolution.
  /// - [errorBuilder]: Custom 404/error page builder.
  /// - [observers]: Navigator observers (e.g. for analytics/telemetry).
  /// - [debugLogDiagnostics]: Enables verbose GoRouter debug logging.
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

  /// Navigates to [location] replacing the current navigation stack.
  ///
  /// Example:
  /// ```dart
  /// BloomRouter.go('/dashboard');
  /// ```
  static void go(String location, {Object? extra}) {
    instance.go(location, extra: extra);
  }

  /// Pushes a new [location] onto the navigation stack.
  ///
  /// Returns a [Future] that completes with the result value when the route is popped.
  ///
  /// Example:
  /// ```dart
  /// final result = await BloomRouter.push<bool>('/modal-dialog');
  /// ```
  static Future<T?> push<T>(String location, {Object? extra}) {
    return instance.push<T>(location, extra: extra);
  }

  /// Pops the topmost route off the navigation stack with an optional [result].
  ///
  /// Example:
  /// ```dart
  /// BloomRouter.pop(true);
  /// ```
  static void pop<T>([T? result]) {
    instance.pop(result);
  }

  /// Replaces the current route on the navigation stack with [location].
  ///
  /// Example:
  /// ```dart
  /// BloomRouter.replace('/settings');
  /// ```
  static void replace(String location, {Object? extra}) {
    instance.replace(location, extra: extra);
  }

  /// Returns the current route URI string from the given [context].
  ///
  /// Example:
  /// ```dart
  /// final url = BloomRouter.currentLocation(context);
  /// ```
  static String currentLocation(BuildContext context) {
    return GoRouterState.of(context).uri.toString();
  }

  /// Dumps the current router state for DevTools inspection.
  static Map<String, dynamic> dumpRouter() {
    return {
      'isInitialized': isInitialized,
      'hasActiveGoRouter': _activeGoRouter != null,
      'pendingDeepLink': BloomDeepLinks.pendingInitialUri?.toString(),
    };
  }

  /// Helper to create a [GoRoute] with Bloom route match and guard resolution.
  ///
  /// Parameters:
  /// - [path]: Route path pattern (e.g. `'/users/:id'`).
  /// - [builder]: Widget builder receiving the current context and [BloomRouteMatch].
  /// - [name]: Optional route name.
  /// - [guards]: Route-specific guards.
  /// - [routes]: Sub-routes nested under this route.
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
  ///
  /// Useful for persistent bottom navigation bars or sidebar layouts.
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
