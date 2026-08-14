// lib/bloom_testing.dart
library bloom_testing;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bloom.dart';

export 'bloom.dart';
export 'package:flutter_test/flutter_test.dart';

/// Extension on [WidgetTester] providing seamless mounting of [BloomApp] in widget tests.
extension BloomWidgetTesterExtension on WidgetTester {
  /// Pumps a [BloomApp] configured with test routes and DI overrides.
  Future<void> pumpBloomApp({
    Widget? home,
    List<RouteBase>? routes,
    String initialLocation = '/',
    ThemeData? theme,
    void Function(BloomContainer container)? configureDependencies,
  }) async {
    Bloom.reset();
    if (configureDependencies != null) {
      configureDependencies(Bloom.container);
    }

    await pumpWidget(
      BloomApp(
        home: home,
        routes: routes,
        initialLocation: initialLocation,
        theme: theme,
      ),
    );
    await pumpAndSettle();
  }
}
