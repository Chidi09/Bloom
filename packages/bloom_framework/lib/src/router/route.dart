// lib/src/router/route.dart
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Metadata match information passed to guards and route builders.
class BloomRouteMatch {
  final String location;
  final String path;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final Object? extra;

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
  final bool isAllowed;
  final String? redirectPath;
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
  const BloomGuard();

  /// Determine whether navigation should be allowed, redirected, or denied.
  FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match);
}

/// Annotation for declaring route metadata on [BloomRoute] classes.
class BloomRouteConfig {
  final String? path;
  final String? name;
  final List<Type> guards;
  final String? title;

  const BloomRouteConfig({
    this.path,
    this.name,
    this.guards = const [],
    this.title,
  });
}

/// Base class for Bloom page/screen widgets.
abstract class BloomRoute extends StatelessWidget {
  const BloomRoute({super.key});
}

/// Base class for persistent shell/tab layouts.
abstract class BloomLayout extends StatelessWidget {
  final Widget child;
  const BloomLayout({super.key, required this.child});
}
