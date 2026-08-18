// lib/bloom_testing.dart
library bloom_testing;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bloom.dart';

export 'package:flutter_test/flutter_test.dart';
export 'bloom.dart';

/// Base class for Bloom service test doubles with call recording utilities.
abstract class BloomMock {
  final Map<String, int> _callCounts = {};

  /// Records a call invocation for the specified [methodName].
  void recordCall(String methodName) {
    _callCounts[methodName] = (_callCounts[methodName] ?? 0) + 1;
  }

  /// Returns the number of times [methodName] was invoked.
  int getCallCount(String methodName) => _callCounts[methodName] ?? 0;

  /// Returns whether [methodName] was called at least once.
  bool wasCalled(String methodName) => (_callCounts[methodName] ?? 0) > 0;

  /// Clears all recorded method call counts.
  void resetMockCalls() => _callCounts.clear();
}

/// Testing utilities and extensions for Bloom applications.
extension BloomWidgetTesterExtensions on WidgetTester {
  /// Pumps a fully configured [BloomApp] within an isolated test scope.
  Future<BloomTestScope> pumpBloomApp({
    String initialLocation = '/',
    List<RouteBase>? routes,
    List<BloomTestOverride<dynamic>>? overrides,
    Widget? home,
    ThemeData? theme,
    Duration settleTimeout = const Duration(seconds: 5),
  }) async {
    Bloom.reset();

    // Create test scope with supplied overrides
    final scope = Bloom.createTestScope(overrides: overrides);
    addTearDown(() => scope.dispose());

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
    return scope;
  }
}
