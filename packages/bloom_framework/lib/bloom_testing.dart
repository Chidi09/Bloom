// lib/bloom_testing.dart
library bloom_testing;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bloom.dart';

export 'package:flutter_test/flutter_test.dart';
export 'bloom.dart';

/// Base class for Bloom service test doubles and mocks.
abstract class BloomMock {
  const BloomMock();
}

/// Testing utilities and extensions for Bloom applications.
extension BloomWidgetTesterExtensions on WidgetTester {
  /// Pumps a fully configured [BloomApp] within an isolated test scope.
  Future<void> pumpBloomApp({
    String initialLocation = '/',
    List<RouteBase>? routes,
    List<BloomTestOverride<dynamic>>? overrides,
    Widget? home,
    ThemeData? theme,
    Duration settleTimeout = const Duration(seconds: 5),
  }) async {
    Bloom.reset();

    // Create test scope with supplied overrides
    Bloom.createTestScope(overrides: overrides);

    final appRoutes = routes ??
        [
          if (home != null)
            BloomRouter.route(
              path: initialLocation,
              builder: (context, match) => home,
            ),
        ];

    await pumpWidget(
      BloomApp(
        title: 'Bloom Test App',
        initialLocation: initialLocation,
        routes: appRoutes,
        theme: theme,
      ),
    );

    await pumpAndSettle(const Duration(milliseconds: 100));
  }
}
