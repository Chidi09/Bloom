/// Declarative routing contracts, match metadata, and route guards for Bloom.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';

/// Metadata match information passed to guards and route builders.
///
/// Contains the matched location URI, path template, path parameters, query parameters,
/// and optional extra arguments passed during navigation.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context, BloomRouteMatch match) {
///   final id = match.pathParameters['id'];
///   return UserProfilePage(userId: id!);
/// }
/// ```
class BloomRouteMatch {
  /// The full matched URI location string (including path and query parameters).
  final String location;

  /// The matched path pattern (e.g. `'/users/:id'`).
  final String path;

  /// Extracted path parameters matching dynamic route segments.
  final Map<String, String> pathParameters;

  /// Query parameters extracted from the location URI.
  final Map<String, String> queryParameters;

  /// Optional extra data payload passed during navigation.
  final Object? extra;

  /// Creates a [BloomRouteMatch] instance.
  const BloomRouteMatch({
    required this.location,
    required this.path,
    this.pathParameters = const {},
    this.queryParameters = const {},
    this.extra,
  });
}

/// The result returned by a [BloomGuard] when evaluating navigation access.
///
/// Determines whether the navigation should proceed ([allow]), redirect to a different
/// route ([redirect]), or be denied with an error ([deny]).
///
/// Example:
/// ```dart
/// if (!isAuthenticated) {
///   return GuardResult.redirect('/login');
/// }
/// return GuardResult.allow();
/// ```
class GuardResult {
  /// Whether navigation to the requested route is permitted.
  final bool isAllowed;

  /// Target redirect route path if navigation is not allowed.
  final String? redirectPath;

  /// Optional explanation message when access is denied.
  final String? denialMessage;

  const GuardResult._({
    required this.isAllowed,
    this.redirectPath,
    this.denialMessage,
  });

  /// Allows navigation to proceed to the target route.
  factory GuardResult.allow() => const GuardResult._(isAllowed: true);

  /// Redirects navigation to a different [path].
  factory GuardResult.redirect(String path) =>
      GuardResult._(isAllowed: false, redirectPath: path);

  /// Denies navigation with an optional explanation [message].
  factory GuardResult.deny([String? message]) =>
      GuardResult._(isAllowed: false, denialMessage: message);
}

/// Abstract contract for route guards (e.g. authentication, role permissions, feature flags).
///
/// Guards run asynchronously before a route is resolved and can redirect or cancel navigation.
///
/// Example:
/// ```dart
/// class AuthGuard extends BloomGuard {
///   const AuthGuard();
///
///   @override
///   FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match) {
///     final auth = inject<AuthService>();
///     return auth.isLoggedIn ? GuardResult.allow() : GuardResult.redirect('/login');
///   }
/// }
/// ```
abstract class BloomGuard {
  /// Creates a [BloomGuard].
  const BloomGuard();

  /// Determines whether navigation to the matched route should be allowed, redirected, or denied.
  FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match);
}

/// Annotation for declaring route metadata and guards on [BloomRoute] classes.
///
/// Example:
/// ```dart
/// @BloomRouteConfig(path: '/dashboard', guards: [AuthGuard], title: 'Dashboard')
/// class DashboardScreen extends BloomRoute {
///   const DashboardScreen({super.key});
///   @override
///   Widget build(BuildContext context) => const Text('Dashboard');
/// }
/// ```
class BloomRouteConfig {
  /// Route path pattern (e.g. `'/profile/:id'`).
  final String? path;

  /// Unique route name identifier.
  final String? name;

  /// List of [BloomGuard] types applied to this route.
  final List<Type> guards;

  /// Page title for SEO and document metadata.
  final String? title;

  /// Creates a [BloomRouteConfig] annotation.
  const BloomRouteConfig({
    this.path,
    this.name,
    this.guards = const [],
    this.title,
  });
}

/// Base class for Bloom page and screen widgets.
///
/// Example:
/// ```dart
/// class HomeScreen extends BloomRoute {
///   const HomeScreen({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return const Scaffold(body: Center(child: Text('Home')));
///   }
/// }
/// ```
abstract class BloomRoute extends StatelessWidget {
  /// Creates a [BloomRoute] widget.
  const BloomRoute({super.key});
}

/// Base class for persistent shell and tab layouts.
///
/// Wraps child routes within common UI elements like sidebars, navigation bars, or footers.
///
/// Example:
/// ```dart
/// class AppLayout extends BloomLayout {
///   const AppLayout({super.key, required super.child});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('App')),
///       body: child,
///     );
///   }
/// }
/// ```
abstract class BloomLayout extends StatelessWidget {
  /// The active child route widget to be rendered inside the layout.
  final Widget child;

  /// Creates a [BloomLayout] wrapping [child].
  const BloomLayout({super.key, required this.child});
}

