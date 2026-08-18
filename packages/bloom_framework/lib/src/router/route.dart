// lib/src/router/route.dart
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Metadata match information passed to guards and route builders.
class BloomRouteMatch {
  /// The full matched URI location string (including path and query).
  final String location;

  /// The matched path pattern.
  final String path;

  /// Extracted path parameters matching dynamic route segments.
  final Map<String, String> pathParameters;

  /// Query parameters extracted from the location URI.
  final Map<String, String> queryParameters;

  /// Optional extra data passed during navigation.
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

/// The result returned by a [BloomGuard].
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

  /// Allows navigation to proceed.
  factory GuardResult.allow() => const GuardResult._(isAllowed: true);

  /// Redirects navigation to a different route.
  factory GuardResult.redirect(String path) =>
      GuardResult._(isAllowed: false, redirectPath: path);

  /// Denies navigation with an optional message.
  factory GuardResult.deny([String? message]) =>
      GuardResult._(isAllowed: false, denialMessage: message);
}

/// Abstract contract for route guards (authentication, permissions, feature flags).
abstract class BloomGuard {
  /// Creates a [BloomGuard].
  const BloomGuard();

  /// Determine whether navigation should be allowed, redirected, or denied.
  FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match);
}

/// Annotation for declaring route metadata on [BloomRoute] classes.
class BloomRouteConfig {
  /// Route path pattern (e.g. `'/profile/:id'`).
  final String? path;

  /// Unique route name identifier.
  final String? name;

  /// List of [BloomGuard] types applied to this route.
  final List<Type> guards;

  /// Page title for SEO/metadata.
  final String? title;

  /// Creates a [BloomRouteConfig] annotation.
  const BloomRouteConfig({
    this.path,
    this.name,
    this.guards = const [],
    this.title,
  });
}

/// Base class for Bloom page/screen widgets.
abstract class BloomRoute extends StatelessWidget {
  /// Creates a [BloomRoute] widget.
  const BloomRoute({super.key});
}

/// Base class for persistent shell/tab layouts.
abstract class BloomLayout extends StatelessWidget {
  /// The active child route widget to be rendered inside the layout.
  final Widget child;

  /// Creates a [BloomLayout] wrapping [child].
  const BloomLayout({super.key, required this.child});
}
