/// Testing harness, mock utilities, and widget testing extensions for Bloom applications.
///
/// Exports `flutter_test`, `bloom.dart`, and provides [BloomMock] for recording method
/// invocations and [BloomWidgetTesterExtensions] for pumping isolated test applications with DI overrides.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_testing.dart';
///
/// void main() {
///   testWidgets('renders home screen with mock service', (tester) async {
///     final scope = await tester.pumpBloomApp(
///       home: const Text('Hello Bloom'),
///       overrides: [
///         BloomTestOverride<AuthService>(MockAuthService()),
///       ],
///     );
///     expect(find.text('Hello Bloom'), findsOneWidget);
///   });
/// }
/// ```
library bloom_testing;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;
import 'bloom.dart';

export 'package:flutter_test/flutter_test.dart';
export 'bloom.dart';

/// Base class for Bloom service test doubles with call recording utilities.
///
/// Subclass this in your test suites to track method invocations and arguments
/// without third-party mocking libraries.
///
/// Example:
/// ```dart
/// class MockAnalyticsService extends BloomMock {
///   void track(String event) {
///     recordCall('track');
///   }
/// }
/// ```
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

/// Testing utilities and extensions on Flutter's [WidgetTester] for Bloom applications.
extension BloomWidgetTesterExtensions on WidgetTester {
  /// Pumps a fully configured [BloomApp] within an isolated test scope.
  ///
  /// Resets global Bloom state and attaches provided [overrides] to the DI container.
  /// Automatically registers a tear-down handler to dispose the test scope when the test finishes.
  ///
  /// Parameters:
  /// - [initialLocation]: The initial route path (defaults to `'/'`).
  /// - [routes]: Custom route configurations for the test.
  /// - [overrides]: DI service overrides for mocking dependencies.
  /// - [home]: A direct root widget to render at [initialLocation].
  /// - [theme]: Custom [ui.BloomTheme] for testing UI themes.
  /// - [settleTimeout]: Maximum duration to wait when settling animations.
  Future<BloomTestScope> pumpBloomApp({
    String initialLocation = '/',
    List<RouteBase>? routes,
    List<BloomTestOverride<dynamic>>? overrides,
    Widget? home,
    ui.BloomTheme? theme,
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
